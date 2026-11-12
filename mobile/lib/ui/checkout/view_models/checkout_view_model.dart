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
    quote.start();
    unawaited(_loadDefaultMethod());
  }

  static const gatewayTime = Duration(minutes: 5);

  final OrderRepository orders;
  final UserRepository users;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;
  final String customerName;
  final DateTime Function() _clock;

  late final CartQuote quote;
  late final Command0<String> place;

  PaymentMethod _method = PaymentMethod.momo;
  bool _methodChosen = false;
  PaymentFailure? _failure;
  DateTime? _gatewayDeadline;
  String? _placedOrderId;
  bool _checkoutLogged = false;

  PaymentMethod get method => _method;
  PaymentFailure? get failure => _failure;
  DateTime? get gatewayDeadline => _gatewayDeadline;
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

  bool get canPlace => items.isNotEmpty && blocker == null && !place.running;

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

  void openGateway() {
    _gatewayDeadline = _clock().add(gatewayTime);
    notifyListeners();
  }

  void failGateway(GatewayOutcome outcome) {
    final failed = _method;
    _failure = PaymentFailure(method: failed, outcome: outcome);
    _gatewayDeadline = null;
    _method = methods.first;
    unawaited(
      analytics.logEvent(AnalyticsEvents.paymentFailed, {'payment_method': failed.name, 'reason': outcome.name}),
    );
    notifyListeners();
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
      case Ok(:final value):
        _placedOrderId = value;
        _gatewayDeadline = null;
        unawaited(
          analytics.logEvent(AnalyticsEvents.purchase, {
            'transaction_id': value,
            'value_vnd': total,
            'payment_method': draft.paymentMethod.name,
          }),
        );
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'checkout.placeOrder');
    }
    notifyListeners();
    return result;
  }

  void retry() => quote.start();

  @override
  void dispose() {
    quote.stop();
    place.dispose();
    super.dispose();
  }
}
