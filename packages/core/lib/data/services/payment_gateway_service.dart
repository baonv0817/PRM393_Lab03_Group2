import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/utils/result.dart';

/// Where a sandbox gateway sends the customer back when the payment ends (D41). The app catches the address inside
/// its WebView before it loads, so no page has to exist there; it sits on the project's Hosting domain because both
/// gateways ask for a web address of the merchant.
abstract final class PaymentReturn {
  static const url = 'https://breakbite-1315b.web.app/payment-return';

  /// MoMo requires a server address for its payment notice (IPN). The project has no server (Spark plan), so nothing
  /// answers it; the app asks MoMo for the result itself instead (D41).
  static const ipnUrl = 'https://breakbite-1315b.web.app/payment-ipn';

  static bool matches(String address) => address.startsWith(url);
}

/// Why the customer left a gateway without paying.
enum GatewayOutcome { declined, expired, cancelled }

/// A payment opened at a sandbox gateway: the page to show and what is needed to check its result.
class GatewayCheckout {
  const GatewayCheckout({
    required this.method,
    required this.orderId,
    required this.amountVnd,
    required this.payUrl,
    this.reference = '',
  });

  final PaymentMethod method;

  /// The BreakBite order the payment is for (the gateway's own order reference is derived from it).
  final String orderId;
  final int amountVnd;
  final Uri payUrl;

  /// The gateway's id of this request (MoMo `requestId`), needed to ask for the result.
  final String reference;
}

sealed class GatewayResult {
  const GatewayResult();
}

/// The gateway confirmed the payment of the whole amount.
final class GatewayPaid extends GatewayResult {
  const GatewayPaid({required this.transactionId});

  /// The gateway's transaction number (MoMo `transId`, VNPAY `vnp_TransactionNo`), shown to the customer if needed.
  final String transactionId;
}

/// The gateway says the payment did not happen. [code] is the gateway's result code, for Analytics.
final class GatewayNotPaid extends GatewayResult {
  const GatewayNotPaid(this.outcome, {this.code = ''});

  final GatewayOutcome outcome;
  final String code;
}

/// A real payment gateway in its sandbox (D41). MoMo and VNPAY go through it; the other methods keep the simulated
/// gateway screen (D02).
abstract interface class PaymentGatewayService {
  /// Whether [method] goes through a sandbox gateway in this build (its keys were given).
  bool supports(PaymentMethod method);

  /// Opens a payment of [amountVnd] for the unpaid order [orderId].
  Future<Result<GatewayCheckout>> start({
    required PaymentMethod method,
    required String orderId,
    required int amountVnd,
  });

  /// Reads the result from the address the gateway sent the customer back to ([PaymentReturn.url]). An error means
  /// the result could not be checked (no network, wrong signature) and the check can be tried again.
  Future<Result<GatewayResult>> finish(GatewayCheckout checkout, Uri returnUri);
}

/// No sandbox gateway: every method uses the simulated screen (no keys in this build, or a test).
class NoPaymentGateway implements PaymentGatewayService {
  const NoPaymentGateway();

  static const _off = ServiceException(message: 'Cổng thanh toán thật chưa được cấu hình.');

  @override
  bool supports(PaymentMethod method) => false;

  @override
  Future<Result<GatewayCheckout>> start({
    required PaymentMethod method,
    required String orderId,
    required int amountVnd,
  }) async => const Result.error(_off);

  @override
  Future<Result<GatewayResult>> finish(GatewayCheckout checkout, Uri returnUri) async => const Result.error(_off);
}
