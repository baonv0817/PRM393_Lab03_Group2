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

enum GatewayOutcome { declined, expired, cancelled }

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
  final DateTime Function() _clock;

  late final CartQuote quote;

  /// Creates the order (D40: always `unpaid`). Cash ends here; a gateway method then opens the gateway.
  late final Command0<String> place;

  /// Pays the order created by [place] at the (simulated) gateway.
  late final Command0<String> pay;

  PaymentMethod _method = PaymentMethod.momo;
  bool _methodChosen = false;
  PaymentFailure? _failure;
  DateTime? _gatewayDeadline;

  /// The gateway order waiting for payment while the gateway is open.
  String? _unpaidOrderId;
  int _paidTotal = 0;
  String? _placedOrderId;
  bool _checkoutLogged = false;

  PaymentMethod get method => _method;
  PaymentFailure? get failure => _failure;
  DateTime? get gatewayDeadline => _gatewayDeadline;
  String? get unpaidOrderId => _unpaidOrderId;
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
      case Ok(:final value):
        _unpaidOrderId = value;
        _paidTotal = total;
        _gatewayDeadline = _clock().add(gatewayTime);
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'checkout.placeOrder');
    }
    notifyListeners();
    return result;
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
    unawaited(
      analytics.logEvent(AnalyticsEvents.purchase, {
        'transaction_id': orderId,
        'value_vnd': total,
        'payment_method': method.name,
      }),
    );
  }

  void retry() => quote.start();

  @override
  void dispose() {
    quote.stop();
    place.dispose();
    pay.dispose();
    super.dispose();
  }
}
