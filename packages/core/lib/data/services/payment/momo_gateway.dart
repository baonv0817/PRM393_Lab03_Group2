import 'dart:async';
import 'dart:convert';

import 'package:breakbite_core/data/services/payment_gateway_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// MoMo test merchant keys, passed with `--dart-define-from-file=env/payment.json` (gitignored). They only work on
/// MoMo's test server ([MomoConfig.sandboxHost]); no real money moves.
class MomoConfig {
  const MomoConfig({
    required this.partnerCode,
    required this.accessKey,
    required this.secretKey,
    this.host = sandboxHost,
  });

  factory MomoConfig.fromEnvironment() => const MomoConfig(
    partnerCode: String.fromEnvironment('MOMO_PARTNER_CODE'),
    accessKey: String.fromEnvironment('MOMO_ACCESS_KEY'),
    secretKey: String.fromEnvironment('MOMO_SECRET_KEY'),
  );

  static const sandboxHost = 'test-payment.momo.vn';

  final String partnerCode;
  final String accessKey;
  final String secretKey;
  final String host;

  bool get isComplete => partnerCode.isNotEmpty && accessKey.isNotEmpty && secretKey.isNotEmpty;
}

/// MoMo payment gateway, API v2 (create + query), in its sandbox (D41).
///
/// [start] creates a `payWithMethod` request signed with HMAC-SHA256 and returns MoMo's `payUrl`, a page where the
/// customer pays with the MoMo app, a test ATM card or a test credit card. MoMo then redirects to [PaymentReturn.url];
/// [finish] does not trust that address alone and asks MoMo for the result with the query API.
class MomoGateway {
  MomoGateway(
    this.config, {
    http.Client? client,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final MomoConfig config;
  final http.Client _client;
  final DateTime Function() _clock;
  final Duration timeout;

  static const requestType = 'payWithMethod';

  /// Codes of MoMo's result table that mean the customer did not pay.
  static const _cancelledCodes = {'1006', '1017'};
  static const _expiredCodes = {'1005'};

  /// The payment is still being processed; asking again later can give the final result.
  static const _pendingCodes = {'1000', '7000', '7002'};

  static String sign(String raw, String secretKey) =>
      Hmac(sha256, utf8.encode(secretKey)).convert(utf8.encode(raw)).toString();

  /// The text MoMo signs for a create request: the fields in alphabetical order, values as they are (not encoded).
  static String createSignatureText({
    required String accessKey,
    required int amount,
    required String extraData,
    required String ipnUrl,
    required String orderId,
    required String orderInfo,
    required String partnerCode,
    required String redirectUrl,
    required String requestId,
    required String requestType,
  }) =>
      'accessKey=$accessKey&amount=$amount&extraData=$extraData&ipnUrl=$ipnUrl&orderId=$orderId'
      '&orderInfo=$orderInfo&partnerCode=$partnerCode&redirectUrl=$redirectUrl&requestId=$requestId'
      '&requestType=$requestType';

  static String querySignatureText({
    required String accessKey,
    required String orderId,
    required String partnerCode,
    required String requestId,
  }) => 'accessKey=$accessKey&orderId=$orderId&partnerCode=$partnerCode&requestId=$requestId';

  Future<Result<GatewayCheckout>> start({required String orderId, required int amountVnd}) async {
    final requestId = '$orderId-${_clock().millisecondsSinceEpoch}';
    final orderInfo = 'BreakBite - don $orderId';
    final signature = sign(
      createSignatureText(
        accessKey: config.accessKey,
        amount: amountVnd,
        extraData: '',
        ipnUrl: PaymentReturn.ipnUrl,
        orderId: orderId,
        orderInfo: orderInfo,
        partnerCode: config.partnerCode,
        redirectUrl: PaymentReturn.url,
        requestId: requestId,
        requestType: requestType,
      ),
      config.secretKey,
    );
    final reply = await _post('/v2/gateway/api/create', {
      'partnerCode': config.partnerCode,
      'requestId': requestId,
      'amount': amountVnd,
      'orderId': orderId,
      'orderInfo': orderInfo,
      'redirectUrl': PaymentReturn.url,
      'ipnUrl': PaymentReturn.ipnUrl,
      'requestType': requestType,
      'extraData': '',
      'lang': 'vi',
      'signature': signature,
    });
    switch (reply) {
      case Err(:final error):
        return Result.error(error);
      case Ok(value: final json):
        final code = '${json['resultCode']}';
        final payUrl = Uri.tryParse('${json['payUrl'] ?? ''}');
        if (code != '0' || payUrl == null || !payUrl.hasScheme) {
          return Result.error(
            ServiceException(message: 'MoMo chưa mở được giao dịch: ${json['message'] ?? 'mã $code'}.', cause: json),
          );
        }
        return Result.ok(
          GatewayCheckout(
            method: PaymentMethod.momo,
            orderId: orderId,
            amountVnd: amountVnd,
            payUrl: payUrl,
            reference: requestId,
          ),
        );
    }
  }

  Future<Result<GatewayResult>> finish(GatewayCheckout checkout, Uri returnUri) async {
    final returned = returnUri.queryParameters['orderId'];
    if (returned != null && returned != checkout.orderId) {
      return const Result.error(ServiceException(message: 'MoMo trả về một giao dịch khác với đơn này.'));
    }
    final signature = sign(
      querySignatureText(
        accessKey: config.accessKey,
        orderId: checkout.orderId,
        partnerCode: config.partnerCode,
        requestId: checkout.reference,
      ),
      config.secretKey,
    );
    final reply = await _post('/v2/gateway/api/query', {
      'partnerCode': config.partnerCode,
      'requestId': checkout.reference,
      'orderId': checkout.orderId,
      'lang': 'vi',
      'signature': signature,
    });
    switch (reply) {
      case Err(:final error):
        return Result.error(error);
      case Ok(value: final json):
        final code = '${json['resultCode']}';
        if (code == '0') {
          if ('${json['amount']}' != '${checkout.amountVnd}') {
            return Result.error(
              ServiceException(message: 'Số tiền MoMo xác nhận không khớp với đơn hàng.', cause: json),
            );
          }
          return Result.ok(GatewayPaid(transactionId: '${json['transId'] ?? ''}'));
        }
        if (_pendingCodes.contains(code)) {
          return const Result.error(
            ServiceException(message: 'MoMo đang xử lý giao dịch. Đợi một chút rồi kiểm tra lại.'),
          );
        }
        final outcome = _cancelledCodes.contains(code)
            ? GatewayOutcome.cancelled
            : _expiredCodes.contains(code)
            ? GatewayOutcome.expired
            : GatewayOutcome.declined;
        return Result.ok(GatewayNotPaid(outcome, code: code));
    }
  }

  Future<Result<Map<String, dynamic>>> _post(String path, Map<String, Object> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.https(config.host, path),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException catch (e, s) {
      return Result.error(NetworkException(message: 'MoMo phản hồi quá lâu. Thử lại.', cause: e, stackTrace: s));
    } on http.ClientException catch (e, s) {
      return Result.error(NetworkException(cause: e, stackTrace: s));
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e, s) {
      return Result.error(
        ServiceException(
          message: 'MoMo trả về dữ liệu không đọc được (HTTP ${response.statusCode}).',
          cause: e,
          stackTrace: s,
        ),
      );
    }
    if (json is! Map<String, dynamic>) {
      return Result.error(ServiceException(message: 'MoMo trả về dữ liệu không hợp lệ.', cause: response.body));
    }
    return Result.ok(json);
  }
}
