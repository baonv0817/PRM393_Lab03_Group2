import 'dart:convert';

import 'package:breakbite_core/data/services/payment_gateway_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:crypto/crypto.dart';

/// VNPAY sandbox merchant keys (the registration e-mail of sandbox.vnpayment.vn), passed with
/// `--dart-define-from-file=env/payment.json` (gitignored).
class VnpayConfig {
  const VnpayConfig({required this.tmnCode, required this.hashSecret, this.payUrl = sandboxPayUrl});

  factory VnpayConfig.fromEnvironment() => const VnpayConfig(
    tmnCode: String.fromEnvironment('VNPAY_TMN_CODE'),
    hashSecret: String.fromEnvironment('VNPAY_HASH_SECRET'),
  );

  static const sandboxPayUrl = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';

  final String tmnCode;
  final String hashSecret;
  final String payUrl;

  bool get isComplete => tmnCode.isNotEmpty && hashSecret.isNotEmpty;
}

/// VNPAY payment gateway, version 2.1.0, in its sandbox (D41).
///
/// [start] needs no request to VNPAY: it builds the payment address signed with HMAC-SHA512. VNPAY sends the customer
/// back to [PaymentReturn.url] with the result and its own signature, which [finish] checks with the same secret.
class VnpayGateway {
  VnpayGateway(this.config, {DateTime Function()? clock, this.timeLimit = const Duration(minutes: 5)})
    : _clock = clock ?? DateTime.now;

  final VnpayConfig config;
  final DateTime Function() _clock;

  /// How long the payment page stays valid (`vnp_ExpireDate`), the same as the gateway countdown of S06-GATEWAY.
  final Duration timeLimit;

  static const _cancelled = '24';
  static const _expired = '11';

  static String sign(String data, String hashSecret) =>
      Hmac(sha512, utf8.encode(hashSecret)).convert(utf8.encode(data)).toString();

  /// The parameters sorted by name and joined as `name=value&…`, each part encoded like PHP `urlencode` (space as
  /// `+`), which is what VNPAY signs on both sides.
  static String canonical(Map<String, String> params) {
    final keys = params.keys.toList()..sort();
    return [for (final k in keys) '${phpUrlEncode(k)}=${phpUrlEncode(params[k]!)}'].join('&');
  }

  static String phpUrlEncode(String value) {
    final out = StringBuffer();
    for (final byte in utf8.encode(value)) {
      final isPlain =
          (byte >= 0x30 && byte <= 0x39) || // 0-9
          (byte >= 0x41 && byte <= 0x5A) || // A-Z
          (byte >= 0x61 && byte <= 0x7A) || // a-z
          byte == 0x2D || // -
          byte == 0x2E || // .
          byte == 0x5F; // _
      if (isPlain) {
        out.writeCharCode(byte);
      } else if (byte == 0x20) {
        out.write('+');
      } else {
        out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  /// VNPAY's clock is Vietnam time (GMT+7), written `yyyyMMddHHmmss`.
  static String vnTime(DateTime time) {
    final t = time.toUtc().add(const Duration(hours: 7));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  Result<GatewayCheckout> start({required String orderId, required int amountVnd}) {
    final now = _clock();
    final params = <String, String>{
      'vnp_Version': '2.1.0',
      'vnp_Command': 'pay',
      'vnp_TmnCode': config.tmnCode,
      'vnp_Amount': '${amountVnd * 100}',
      'vnp_CurrCode': 'VND',
      'vnp_TxnRef': orderId,
      'vnp_OrderInfo': 'Thanh toan don BreakBite $orderId',
      'vnp_OrderType': 'other',
      'vnp_Locale': 'vn',
      'vnp_ReturnUrl': PaymentReturn.url,
      // A phone app has no address of its own on the Internet; VNPAY only records this value.
      'vnp_IpAddr': '127.0.0.1',
      'vnp_CreateDate': vnTime(now),
      'vnp_ExpireDate': vnTime(now.add(timeLimit)),
    };
    final data = canonical(params);
    final url = Uri.parse('${config.payUrl}?$data&vnp_SecureHash=${sign(data, config.hashSecret)}');
    return Result.ok(GatewayCheckout(method: PaymentMethod.vnpay, orderId: orderId, amountVnd: amountVnd, payUrl: url));
  }

  Result<GatewayResult> finish(GatewayCheckout checkout, Uri returnUri) {
    final query = returnUri.queryParameters;
    final received = query['vnp_SecureHash'] ?? '';
    final signed = {
      for (final e in query.entries)
        if (e.key.startsWith('vnp_') && e.key != 'vnp_SecureHash' && e.key != 'vnp_SecureHashType') e.key: e.value,
    };
    if (received.isEmpty || sign(canonical(signed), config.hashSecret).toLowerCase() != received.toLowerCase()) {
      return const Result.error(ServiceException(message: 'Chữ ký kết quả của VNPAY không đúng, không thể xác nhận.'));
    }
    if (signed['vnp_TxnRef'] != checkout.orderId) {
      return const Result.error(ServiceException(message: 'VNPAY trả về một giao dịch khác với đơn này.'));
    }
    final code = signed['vnp_ResponseCode'] ?? '';
    if (code == '00' && signed['vnp_TransactionStatus'] == '00') {
      if (signed['vnp_Amount'] != '${checkout.amountVnd * 100}') {
        return const Result.error(ServiceException(message: 'Số tiền VNPAY xác nhận không khớp với đơn hàng.'));
      }
      return Result.ok(GatewayPaid(transactionId: signed['vnp_TransactionNo'] ?? ''));
    }
    final outcome = switch (code) {
      _cancelled => GatewayOutcome.cancelled,
      _expired => GatewayOutcome.expired,
      _ => GatewayOutcome.declined,
    };
    return Result.ok(GatewayNotPaid(outcome, code: code));
  }
}
