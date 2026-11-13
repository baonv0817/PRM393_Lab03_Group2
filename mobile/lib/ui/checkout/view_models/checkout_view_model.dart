import 'dart:async';

import 'package:breakbite/ui/cart/view_models/cart_quote.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/domain/order_pricing.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

export 'package:breakbite_core/data/services/payment_gateway_service.dart' show GatewayCheckout, GatewayOutcome;

class PaymentFailure {
  const PaymentFailure({required this.method, required this.outcome});

  final PaymentMethod method;
  final GatewayOutcome outcome;
}

class CheckoutViewModel extends ChangeNotifier with SafeChangeNotifier {
  CheckoutViewModel({
    required CartRepository cart,
    required MenuRepository menu,
    required this.orders,
    required this.users,
    required this.analytics,
    required this.crash,
    required this.uid,
    required this.customerName,
    this.gateway = const NoPaymentGateway(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    quote = CartQuote(
      cart: cart,
      menu: menu,
      crash: crash,
      uid: uid,
      onChanged: _changed,
      clock: _clock,
      reason: 'checkout',
    );
    place = Command0(_place);
    pay = Command0(_pay);
    complete = Command1(_complete);
    quote.start();
    unawaited(_loadDefaultMethod());
  }

  static const gatewayTime = Duration(minutes: 5);
  static const unpaidCancelReason = 'Thanh toán không thành công';

  final OrderRepository orders;
  final UserRepository users;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;
  final String customerName;

  /// The sandbox gateways (D41). A method it does not support keeps the simulated screen (D02).
  final PaymentGatewayService gateway;
  final DateTime Function() _clock;

  late final CartQuote quote;

  /// Creates the order (D40: always `unpaid`). Cash ends here; a gateway method then opens the gateway.
  late final Command0<String> place;

  /// Pays the order created by [place] at the (simulated) gateway.
  late final Command0<String> pay;

  /// Checks the result the sandbox gateway sent back ([PaymentReturn.url]) and pays the order when it is paid. The
  /// value is the order id when paid, null when the gateway said it was not paid ([failure] is then set).
  late final Command1<String?, Uri> complete;

  PaymentMethod _method = PaymentMethod.momo;
  bool _methodChosen = false;
  PaymentFailure? _failure;
  DateTime? _gatewayDeadline;
  GatewayCheckout? _checkout;
  String _gatewayTransaction = '';

  /// The gateway order waiting for payment while the gateway is open.
  String? _unpaidOrderId;
  int _paidTotal = 0;
  String? _placedOrderId;
  bool _checkoutLogged = false;

  PaymentMethod get method => _method;
  PaymentFailure? get failure => _failure;
  DateTime? get gatewayDeadline => _gatewayDeadline;
  String? get unpaidOrderId => _unpaidOrderId;

  /// The sandbox payment page while it is open; null when the simulated screen is used.
  GatewayCheckout? get checkout => _checkout;
  bool get usesSandbox => gateway.supports(_method);
  DateTime get now => _clock();
  bool get needsGateway => _method != PaymentMethod.cash;
  List<CartItem> get items => quote.value.items;
  Kiosk? get kiosk => quote.kiosk;
  OrderPricing get pricing => quote.price(items);

  List<PaymentMethod> get methods => [
    for (final m in PaymentMethod.values)
      if (m != _failure?.method) m,
  ];

  ViewState<List<CartItem>> get state {
    if (quote.loadError case final message?) return ViewError(message);
    if (!quote.loaded) return const ViewLoading();
    if (_placedOrderId != null) return ViewData(items);
    return ViewStateX.fromList(items, emptyMessage: 'Giỏ hàng đang trống, không có gì để thanh toán.');
  }

  String? get blocker {
    if (quote.kioskProblem case final message?) return message;
    if (quote.voucherProblem(pricing.subtotalVnd) case final message?) return '$message Quay lại giỏ hàng để bỏ mã.';
    return null;
  }

  bool get canPlace => items.isNotEmpty && blocker == null && !place.running && _unpaidOrderId == null;

  void _changed() {
    if (!_checkoutLogged && quote.loaded && items.isNotEmpty) {
      _checkoutLogged = true;
      unawaited(
        analytics.logEvent(AnalyticsEvents.beginCheckout, {
          'value_vnd': pricing.totalVnd,
          'item_count': quote.value.itemCount,
        }),
      );
    }
    notifyListeners();
  }

  Future<void> _loadDefaultMethod() async {
    try {
      final profile = await users.watchProfile(uid).first;
      if (_methodChosen || _failure != null) return;
      if (profile.defaultPaymentMethod case final saved?) {
        _method = saved;
        notifyListeners();
      }
    } on Object catch (error, stack) {
      crash.recordNonFatal(error, stack, 'checkout.defaultMethod');
    }
  }

  void choose(PaymentMethod method) {
    _method = method;
    _methodChosen = true;
    notifyListeners();
  }

  /// Leaving the gateway without paying cancels the unpaid order, which releases its pickup slot; the
  /// cart was never emptied, so S06-ERR offers another method with the same items (D40).
  Future<void> failGateway(GatewayOutcome outcome) async {
    final failed = _method;
    final orderId = _unpaidOrderId;
    _failure = PaymentFailure(method: failed, outcome: outcome);
    _gatewayDeadline = null;
    _unpaidOrderId = null;
    _checkout = null;
    _method = methods.first;
    unawaited(
      analytics.logEvent(AnalyticsEvents.paymentFailed, {'payment_method': failed.name, 'reason': outcome.name}),
    );
    notifyListeners();
    if (orderId != null) await _cancelUnpaid(orderId);
  }

  Future<void> _cancelUnpaid(String orderId) async {
    try {
      final order = await orders.watchOrder(orderId).first;
      if (order == null || !order.awaitingPayment) return;
      if (await orders.cancelMyOrder(order, reason: unpaidCancelReason) case Err(:final error)) {
        crash.recordNonFatal(error, error.stackTrace, 'checkout.cancelUnpaid');
      }
    } on Object catch (error, stack) {
      crash.recordNonFatal(error, stack, 'checkout.cancelUnpaid');
    }
  }

  OrderDraft? _draft() {
    final kioskId = quote.value.kioskId;
    final k = kiosk;
    if (kioskId == null || k == null || items.isEmpty) return null;
    return OrderDraft(
      uid: uid,
      customerName: customerName,
      kioskId: kioskId,
      kioskName: k.name,
      items: items,
      paymentMethod: _method,
      voucherCode: quote.value.voucherCode,
      pickupSlotId: quote.value.pickupSlotId,
    );
  }

  Future<Result<String>> _place() async {
    final draft = _draft();
    if (draft == null) return const Result.error(ValidationException('Giỏ hàng đang trống.'));
    if (blocker case final message?) return Result.error(ValidationException(message));
    final total = pricing.totalVnd;
    final result = await orders.placeOrder(draft);
    switch (result) {
      case Ok(:final value) when draft.paymentMethod == PaymentMethod.cash:
        _placed(value, total, draft.paymentMethod);
      case Ok(:final value) when gateway.supports(draft.paymentMethod):
        final opened = await gateway.start(method: draft.paymentMethod, orderId: value, amountVnd: total);
        switch (opened) {
          case Ok(value: final checkout):
            _openGateway(value, total);
            _checkout = checkout;
          case Err(:final error):
            // The gateway page could not be opened: cancel the unpaid order so its slot is free again; the cart
            // is still there for another try or another method.
            crash.recordNonFatal(error, error.stackTrace, 'checkout.gatewayStart');
            await _cancelUnpaid(value);
            notifyListeners();
            return Result.error(error);
        }
      case Ok(:final value):
        _openGateway(value, total);
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'checkout.placeOrder');
    }
    notifyListeners();
    return result;
  }

  void _openGateway(String orderId, int total) {
    _unpaidOrderId = orderId;
    _paidTotal = total;
    _gatewayDeadline = _clock().add(gatewayTime);
  }

  Future<Result<String?>> _complete(Uri returnUri) async {
    final checkout = _checkout;
    if (checkout == null || _unpaidOrderId == null) {
      return const Result.error(ValidationException('Giao dịch đã kết thúc. Quay lại để đặt lại.'));
    }
    final checked = await gateway.finish(checkout, returnUri);
    switch (checked) {
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'checkout.gatewayFinish');
        return Result.error(error);
      case Ok(value: GatewayNotPaid(:final outcome)):
        await failGateway(outcome);
        return const Result.ok(null);
      case Ok(value: GatewayPaid(:final transactionId)):
        _gatewayTransaction = transactionId;
        final paid = await _pay();
        return switch (paid) {
          Ok(:final value) => Result.ok(value),
          Err(:final error) => Result.error(error),
        };
    }
  }

  Future<Result<String>> _pay() async {
    final orderId = _unpaidOrderId;
    if (orderId == null) return const Result.error(ValidationException('Đơn chưa được tạo. Quay lại để đặt lại.'));
    final method = _method;
    final result = await orders.payOrder(orderId);
    switch (result) {
      case Ok():
        _unpaidOrderId = null;
        _placed(orderId, _paidTotal, method);
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'checkout.payOrder');
    }
    notifyListeners();
    return switch (result) {
      Ok() => Result.ok(orderId),
      Err(:final error) => Result.error(error),
    };
  }

  void _placed(String orderId, int total, PaymentMethod method) {
    _placedOrderId = orderId;
    _gatewayDeadline = null;
    final sandbox = _checkout != null;
    _checkout = null;
    unawaited(
      analytics.logEvent(AnalyticsEvents.purchase, {
        'transaction_id': orderId,
        'value_vnd': total,
        'payment_method': method.name,
        if (sandbox) 'gateway': 'sandbox',
        if (_gatewayTransaction.isNotEmpty) 'gateway_txn': _gatewayTransaction,
      }),
    );
  }

  void retry() => quote.start();

  @override
  void dispose() {
    quote.stop();
    place.dispose();
    pay.dispose();
    complete.dispose();
    super.dispose();
  }
}
