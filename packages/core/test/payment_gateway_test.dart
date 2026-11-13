import 'dart:convert';

import 'package:breakbite_core/data/services/payment/momo_gateway.dart';
import 'package:breakbite_core/data/services/payment/sandbox_payment_gateway.dart';
import 'package:breakbite_core/data/services/payment/vnpay_gateway.dart';
import 'package:breakbite_core/data/services/payment_gateway_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Made-up keys: these tests never reach MoMo or VNPAY.
const _momo = MomoConfig(partnerCode: 'PARTNER', accessKey: 'ACCESS', secretKey: 'SECRET');
const _vnpay = VnpayConfig(tmnCode: 'TMNCODE1', hashSecret: 'HASHSECRET');
final _now = DateTime.utc(2026, 11, 13, 3, 4, 5); // 10:04:05 in Vietnam

T _ok<T>(Result<T> result) => (result as Ok<T>).value;

void main() {
  group('MoMo', () {
    test('HMAC-SHA256 gives the known value (RFC 4231 test case 2)', () {
      expect(
        MomoGateway.sign('what do ya want for nothing?', 'Jefe'),
        '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
      );
    });

    test('the create request is signed over the fields in MoMo order and returns the payUrl', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://test-payment.momo.vn/v2/gateway/api/create');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'resultCode': 0, 'payUrl': 'https://test-payment.momo.vn/pay/abc'}), 200);
      });
      final gateway = MomoGateway(_momo, client: client, clock: () => _now);
      final checkout = _ok(await gateway.start(orderId: 'ord1', amountVnd: 39000));

      final requestId = 'ord1-${_now.millisecondsSinceEpoch}';
      expect(sent['requestId'], requestId);
      expect(sent['amount'], 39000);
      expect(sent['redirectUrl'], PaymentReturn.url);
      expect(sent['requestType'], 'payWithMethod');
      final text =
          'accessKey=ACCESS&amount=39000&extraData=&ipnUrl=${PaymentReturn.ipnUrl}&orderId=ord1'
          '&orderInfo=BreakBite - don ord1&partnerCode=PARTNER&redirectUrl=${PaymentReturn.url}'
          '&requestId=$requestId&requestType=payWithMethod';
      expect(sent['signature'], MomoGateway.sign(text, 'SECRET'));
      expect(checkout.payUrl.toString(), 'https://test-payment.momo.vn/pay/abc');
      expect(checkout.reference, requestId);
      expect(checkout.method, PaymentMethod.momo);
    });

    test('a refused create request is an error with MoMo\'s message', () async {
      final client = MockClient(
        (_) async => http.Response.bytes(utf8.encode(jsonEncode({'resultCode': 13, 'message': 'Sai chữ ký'})), 200),
      );
      final result = await MomoGateway(_momo, client: client).start(orderId: 'ord1', amountVnd: 39000);
      expect((result as Err).error.message, contains('Sai chữ ký'));
    });

    GatewayCheckout checkout() => GatewayCheckout(
      method: PaymentMethod.momo,
      orderId: 'ord1',
      amountVnd: 39000,
      payUrl: Uri.parse('https://test-payment.momo.vn/pay/abc'),
      reference: 'ord1-1',
    );

    MomoGateway answering(Map<String, Object> reply, {void Function(Map<String, dynamic>)? onQuery}) => MomoGateway(
      _momo,
      client: MockClient((request) async {
        expect(request.url.path, '/v2/gateway/api/query');
        onQuery?.call(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode(reply), 200);
      }),
    );

    final back = Uri.parse('${PaymentReturn.url}?orderId=ord1&resultCode=0');

    test('finish asks MoMo with a signed query and accepts only the whole amount', () async {
      late Map<String, dynamic> query;
      final gateway = answering({'resultCode': 0, 'amount': 39000, 'transId': 4100000001}, onQuery: (q) => query = q);
      final result = _ok(await gateway.finish(checkout(), back));
      expect((result as GatewayPaid).transactionId, '4100000001');
      expect(query['requestId'], 'ord1-1');
      expect(
        query['signature'],
        MomoGateway.sign('accessKey=ACCESS&orderId=ord1&partnerCode=PARTNER&requestId=ord1-1', 'SECRET'),
      );

      final short = await answering({'resultCode': 0, 'amount': 1000}).finish(checkout(), back);
      expect(short, isA<Err<GatewayResult>>());
    });

    test('MoMo codes map to cancelled, expired, declined, or "still processing"', () async {
      Future<Object> outcome(int code) async =>
          switch (await answering({'resultCode': code}).finish(checkout(), back)) {
            Ok(value: GatewayNotPaid(:final outcome)) => outcome,
            Ok() => 'paid',
            Err() => 'error',
          };
      expect(await outcome(1006), GatewayOutcome.cancelled);
      expect(await outcome(1005), GatewayOutcome.expired);
      expect(await outcome(1001), GatewayOutcome.declined);
      expect(await outcome(7000), 'error');
    });

    test('a return address of another order is refused without asking MoMo', () async {
      final gateway = MomoGateway(_momo, client: MockClient((_) async => fail('no request expected')));
      final result = await gateway.finish(checkout(), Uri.parse('${PaymentReturn.url}?orderId=other'));
      expect(result, isA<Err<GatewayResult>>());
    });

    test('no network is a NetworkException', () async {
      final gateway = MomoGateway(_momo, client: MockClient((_) async => throw http.ClientException('offline')));
      final result = await gateway.start(orderId: 'ord1', amountVnd: 39000);
      expect((result as Err).error, isA<NetworkException>());
    });
  });

  group('VNPAY', () {
    test('HMAC-SHA512 gives the known value (RFC 4231 test case 2)', () {
      expect(
        VnpayGateway.sign('what do ya want for nothing?', 'Jefe'),
        '164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea250554'
        '9758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737',
      );
    });

    test('values are encoded like PHP urlencode', () {
      expect(VnpayGateway.phpUrlEncode('Thanh toan don A-1_b.c'), 'Thanh+toan+don+A-1_b.c');
      expect(VnpayGateway.phpUrlEncode('https://x.vn/a?b=1~'), 'https%3A%2F%2Fx.vn%2Fa%3Fb%3D1%7E');
      expect(VnpayGateway.phpUrlEncode('đ'), '%C4%91');
    });

    test('the payment address has the order, the amount × 100, Vietnam time and a valid signature', () {
      final checkout = _ok(VnpayGateway(_vnpay, clock: () => _now).start(orderId: 'ord1', amountVnd: 39000));
      final url = checkout.payUrl;
      expect('${url.scheme}://${url.host}${url.path}', VnpayConfig.sandboxPayUrl);
      final q = url.queryParameters;
      expect(q['vnp_TmnCode'], 'TMNCODE1');
      expect(q['vnp_Amount'], '3900000');
      expect(q['vnp_TxnRef'], 'ord1');
      expect(q['vnp_CreateDate'], '20261113100405');
      expect(q['vnp_ExpireDate'], '20261113100905');
      expect(q['vnp_ReturnUrl'], PaymentReturn.url);
      final signed = Map.of(q)..remove('vnp_SecureHash');
      expect(q['vnp_SecureHash'], VnpayGateway.sign(VnpayGateway.canonical(signed), 'HASHSECRET'));
      // The signed text is exactly the query before the hash, as VNPAY checks it.
      expect(url.query, '${VnpayGateway.canonical(signed)}&vnp_SecureHash=${q['vnp_SecureHash']}');
    });

    final gateway = VnpayGateway(_vnpay);
    final checkout = GatewayCheckout(
      method: PaymentMethod.vnpay,
      orderId: 'ord1',
      amountVnd: 39000,
      payUrl: Uri.parse(VnpayConfig.sandboxPayUrl),
    );

    Uri back(Map<String, String> params, {String secret = 'HASHSECRET'}) {
      final all = {
        'vnp_TmnCode': 'TMNCODE1',
        'vnp_TxnRef': 'ord1',
        'vnp_Amount': '3900000',
        'vnp_OrderInfo': 'Thanh toan don BreakBite ord1',
        'vnp_TransactionNo': '14123456',
        'vnp_BankCode': 'NCB',
        ...params,
      };
      final data = VnpayGateway.canonical(all);
      return Uri.parse(
        '${PaymentReturn.url}?$data&vnp_SecureHashType=HmacSHA512&vnp_SecureHash=${VnpayGateway.sign(data, secret)}',
      );
    }

    test('a signed success return pays the order', () {
      final result = _ok(gateway.finish(checkout, back({'vnp_ResponseCode': '00', 'vnp_TransactionStatus': '00'})));
      expect((result as GatewayPaid).transactionId, '14123456');
    });

    test('a wrong signature, another order or another amount is refused', () {
      final ok = {'vnp_ResponseCode': '00', 'vnp_TransactionStatus': '00'};
      expect(gateway.finish(checkout, back(ok, secret: 'OTHER')), isA<Err<GatewayResult>>());
      expect(gateway.finish(checkout, back({...ok, 'vnp_TxnRef': 'ord2'})), isA<Err<GatewayResult>>());
      expect(gateway.finish(checkout, back({...ok, 'vnp_Amount': '100000'})), isA<Err<GatewayResult>>());
      final tampered = Uri.parse(back(ok).toString().replaceFirst('vnp_Amount=3900000', 'vnp_Amount=100'));
      expect(gateway.finish(checkout, tampered), isA<Err<GatewayResult>>());
    });

    test('VNPAY codes map to cancelled (24), expired (11) and declined', () {
      GatewayOutcome outcome(String code) => (_ok(
        gateway.finish(checkout, back({'vnp_ResponseCode': code, 'vnp_TransactionStatus': '02'})),
      ) as GatewayNotPaid).outcome;
      expect(outcome('24'), GatewayOutcome.cancelled);
      expect(outcome('11'), GatewayOutcome.expired);
      expect(outcome('51'), GatewayOutcome.declined);
    });
  });

  group('SandboxPaymentGateway', () {
    test('supports only the methods whose keys were given; card and cash stay simulated', () {
      final both = SandboxPaymentGateway(momo: MomoGateway(_momo), vnpay: VnpayGateway(_vnpay));
      expect(PaymentMethod.values.where(both.supports), [PaymentMethod.momo, PaymentMethod.vnpay]);
      final momoOnly = SandboxPaymentGateway(momo: MomoGateway(_momo));
      expect(momoOnly.supports(PaymentMethod.vnpay), isFalse);
      expect(const NoPaymentGateway().supports(PaymentMethod.momo), isFalse);
    });

    test('without dart-defines the build has no sandbox gateway', () {
      final fromEnv = SandboxPaymentGateway.fromEnvironment();
      expect(fromEnv.momo, isNull);
      expect(fromEnv.vnpay, isNull);
    });

    test('an amount below 1.000đ is refused before reaching a gateway', () async {
      final both = SandboxPaymentGateway(vnpay: VnpayGateway(_vnpay));
      final result = await both.start(method: PaymentMethod.vnpay, orderId: 'ord1', amountVnd: 500);
      expect((result as Err).error, isA<ValidationException>());
    });
  });
}
