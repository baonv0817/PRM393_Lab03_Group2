import 'dart:async';

import 'package:breakbite/data/repositories/notification_repository.dart';
import 'package:breakbite/data/repositories/order_repository.dart';
import 'package:breakbite/data/services/crash_service.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

/// Writes a notification into the customer's inbox (S19) when an order of theirs moves on: accepted, ready,
/// handed over, or turned down. The app has no server (data-model section 6), so the app does it itself
/// while it is open; the id `{orderId}_{status}` makes the same change seen twice one notification.
///
/// The first snapshot only records where every order stands, so opening the app does not announce old
/// changes; only what happens afterwards does.
class OrderStatusNotifier {
  OrderStatusNotifier({
    required this.orders,
    required this.notifications,
    required this.crash,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final OrderRepository orders;
  final NotificationRepository notifications;
  final CrashService crash;
  final DateTime Function() _clock;

  StreamSubscription<List<Order>>? _ordersSub;
  StreamSubscription<NotificationPrefs>? _prefsSub;
  final _seen = <String, OrderStatus>{};
  var _prefs = NotificationPrefs.defaults;
  var _first = true;
  String? _uid;

  /// Starts watching the orders of [uid]. Calling it again for another customer starts over.
  void start(String uid) {
    stop();
    _uid = uid;
    _first = true;
    _prefsSub = notifications
        .watchPrefs(uid)
        .listen(
          (prefs) => _prefs = prefs,
          onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'orderNotifier.watchPrefs'),
        );
    _ordersSub = orders
        .watchMyOrders(uid, limit: 20)
        .listen(
          _onOrders,
          onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'orderNotifier.watchOrders'),
        );
  }

  void stop() {
    unawaited(_ordersSub?.cancel());
    unawaited(_prefsSub?.cancel());
    _ordersSub = null;
    _prefsSub = null;
    _seen.clear();
    _prefs = NotificationPrefs.defaults;
    _uid = null;
  }

  void _onOrders(List<Order> list) {
    final uid = _uid;
    if (uid == null) return;
    for (final order in list) {
      final before = _seen[order.id];
      _seen[order.id] = order.status;
      // An order met for the first time is not a change: the first snapshot may be partial (a cache that is
      // still filling), so old orders arriving in a later one must not be announced either.
      if (_first || before == null || before == order.status) continue;
      final message = messageFor(order, before: before);
      if (message == null || !_wants(order.status)) continue;
      unawaited(_save(uid, order, message));
    }
    _first = false;
  }

  bool _wants(OrderStatus status) => status == OrderStatus.ready ? _prefs.orderReady : _prefs.orderUpdates;

  Future<void> _save(String uid, Order order, ({String title, String body}) message) async {
    final result = await notifications.save(
      uid,
      AppNotification(
        id: AppNotification.idForOrder(order.id, order.status),
        title: message.title,
        body: message.body,
        receivedAt: _clock(),
        orderId: order.id,
      ),
    );
    if (result case Err<void>(:final error)) crash.recordNonFatal(error, error.stackTrace, 'orderNotifier.save');
  }

  /// What the customer reads for [order] in its new state, or `null` when nothing is worth saying.
  static ({String title, String body})? messageFor(Order order, {OrderStatus? before}) {
    final code = order.orderCode.isEmpty ? order.id : order.orderCode;
    final where = order.kioskName.isEmpty ? '' : ' tại ${order.kioskName}';
    return switch (order.status) {
      OrderStatus.preparing => (title: 'Đơn #$code đang được làm', body: 'Kiosk đã nhận đơn của bạn và bắt đầu làm.'),
      OrderStatus.ready => (title: 'Đơn #$code đã sẵn sàng', body: 'Nhận món$where bằng mã nhận món của đơn.'),
      OrderStatus.delivered => (title: 'Đơn #$code đã hoàn tất', body: 'Bạn đã nhận món. Chúc ngon miệng!'),
      OrderStatus.cancelled when order.cancelledBy == CancelledBy.staff => (
        title: 'Đơn #$code bị từ chối',
        body: order.cancelReason == null || order.cancelReason!.isEmpty
            ? 'Kiosk không nhận được đơn này. Bạn được hoàn tiền.'
            : 'Lý do: ${order.cancelReason}. Bạn được hoàn tiền.',
      ),
      _ => null,
    };
  }
}
