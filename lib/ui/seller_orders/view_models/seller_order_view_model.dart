import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_order_actions.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// K03 (an order), K04 (making it), K06 and K06-CASH (handing it over), K12 (turning it down): one order of
/// the kiosk, followed live, with the four things staff can do to it.
class SellerOrderViewModel extends ChangeNotifier with SafeChangeNotifier {
  SellerOrderViewModel({
    required this.orders,
    required this.menu,
    required this.crash,
    required this.analytics,
    required this.orderId,
    required this.kioskId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    load();
  }

  static const notYoursMessage = 'Đơn này không thuộc kiosk của bạn.';
  static const notFoundMessage = 'Không tìm thấy đơn này.';

  final OrderRepository orders;
  final MenuRepository menu;
  final CrashService crash;
  final AnalyticsService analytics;
  final String orderId;
  final String? kioskId;
  final DateTime Function() _clock;

  StreamSubscription<Order?>? _sub;
  ViewState<Order> _state = const ViewLoading();
  int? _kioskWait;
  bool _busy = false;
  final _checked = <int>{};

  ViewState<Order> get state => _state;
  Order? get order => _state.dataOrNull;
  DateTime get now => _clock();
  bool get busy => _busy;

  /// Lines of K04 the cook has ticked off, by position in the order.
  Set<int> get checked => Set.unmodifiable(_checked);

  bool isChecked(int index) => _checked.contains(index);

  bool get allChecked => order != null && _checked.length == order!.items.length;

  void toggle(int index) {
    if (!_checked.add(index)) _checked.remove(index);
    notifyListeners();
  }

  /// K06-CASH: the customer has not paid yet, so the money is collected before the food goes out.
  bool get isCashToCollect => order != null && order!.paymentStatus == PaymentStatus.unpaid;

  /// The "Nhận lúc 10:25" line: the pickup time the customer chose, or when the kitchen promised it.
  DateTime? get pickupTime => order?.pickupAt ?? order?.readyBy;

  /// Time left until the order must be ready (the countdown of K04); `null` before it is accepted.
  Duration? get timeLeft => order?.readyBy?.difference(now);

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    unawaited(
      menu.watchKiosks().first.then(
        (kiosks) => _kioskWait = kiosks.where((k) => k.id == kioskId).firstOrNull?.waitMinutes,
        onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'sellerOrder.watchKiosks'),
      ),
    );
    _sub = orders
        .watchOrder(orderId)
        .listen(
          (order) {
            if (order == null) {
              _state = const ViewEmpty(notFoundMessage);
            } else if (kioskId != null && order.kioskId != kioskId) {
              _state = const ViewEmpty(notYoursMessage);
            } else {
              _state = ViewData(order);
            }
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'sellerOrder.watchOrder');
            _state = ViewError(error is AppException ? error.message : 'Không tải được đơn.');
            notifyListeners();
          },
        );
  }

  Future<Result<void>> accept() => _run(
    'accept',
    (o) => orders.accept(
      o,
      readyIn: readyInFor(o, now: now, kioskWaitMinutes: _kioskWait),
    ),
    onDone: (o) => logOrderAccepted(analytics, o, now),
  );

  Future<Result<void>> markReady() => _run('markReady', orders.markReady);

  Future<Result<void>> deliver() => _run('deliver', orders.deliver, onDone: (o) => logOrderDelivered(analytics, o));

  /// K12: [reason] is the text of `rejectReasonText`. The customer is refunded automatically (D04).
  Future<Result<void>> reject(String reason) {
    if (reason.trim().isEmpty) {
      return Future.value(const Result.error(ValidationException('Chọn lý do từ chối đơn.')));
    }
    return _run('reject', (o) => orders.reject(o, reason: reason.trim()));
  }

  Future<Result<void>> _run(
    String name,
    Future<Result<void>> Function(Order order) action, {
    void Function(Order order)? onDone,
  }) async {
    final current = order;
    if (current == null) return const Result.error(NotFoundException(message: notFoundMessage));
    if (_busy) return const Result.ok(null);
    _busy = true;
    notifyListeners();
    try {
      final result = await action(current);
      switch (result) {
        case Ok():
          onDone?.call(current);
        case Err(:final error):
          crash.recordNonFatal(error, error.stackTrace, 'sellerOrder.$name');
      }
      return result;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
