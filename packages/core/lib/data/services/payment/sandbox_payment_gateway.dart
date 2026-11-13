import 'package:breakbite_core/data/services/payment/momo_gateway.dart';
import 'package:breakbite_core/data/services/payment/vnpay_gateway.dart';
import 'package:breakbite_core/data/services/payment_gateway_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/utils/result.dart';

/// The sandbox gateways whose keys this build has (D41): MoMo, VNPAY, both or none.
class SandboxPaymentGateway implements PaymentGatewayService {
  SandboxPaymentGateway({this.momo, this.vnpay});

  factory SandboxPaymentGateway.fromEnvironment() {
    final momo = MomoConfig.fromEnvironment();
    final vnpay = VnpayConfig.fromEnvironment();
    return SandboxPaymentGateway(
      momo: momo.isComplete ? MomoGateway(momo) : null,
      vnpay: vnpay.isComplete ? VnpayGateway(vnpay) : null,
    );
  }

  final MomoGateway? momo;
  final VnpayGateway? vnpay;

  static const _missing = ServiceException(message: 'Phương thức này chưa có cổng thanh toán thật.');

  @override
  bool supports(PaymentMethod method) => switch (method) {
    PaymentMethod.momo => momo != null,
    PaymentMethod.vnpay => vnpay != null,
    PaymentMethod.card || PaymentMethod.cash => false,
  };

  @override
  Future<Result<GatewayCheckout>> start({
    required PaymentMethod method,
    required String orderId,
    required int amountVnd,
  }) async {
    if (amountVnd < 1000) {
      return const Result.error(ValidationException('Cổng thanh toán chỉ nhận đơn từ 1.000đ trở lên.'));
    }
    if (method == PaymentMethod.momo && momo != null) return momo!.start(orderId: orderId, amountVnd: amountVnd);
    if (method == PaymentMethod.vnpay && vnpay != null) return vnpay!.start(orderId: orderId, amountVnd: amountVnd);
    return const Result.error(_missing);
  }

  @override
  Future<Result<GatewayResult>> finish(GatewayCheckout checkout, Uri returnUri) async {
    if (checkout.method == PaymentMethod.momo && momo != null) return momo!.finish(checkout, returnUri);
    if (checkout.method == PaymentMethod.vnpay && vnpay != null) return vnpay!.finish(checkout, returnUri);
    return const Result.error(_missing);
  }
}
