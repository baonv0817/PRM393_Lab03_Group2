import 'dart:async';

import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

class OrdersViewModel extends ChangeNotifier with SafeChangeNotifier {
  OrdersViewModel({
    required this.orders,
    required this.cart,
    required this.session,
    required this.analytics,
    required this.crash,
    required this.uid,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    reorder = Command1(_reorder);
    load();
  }

  static const emptyMessage = 'Chưa có đơn nào. Đặt món trước giờ nghỉ để không phải xếp hàng.';
  static const recentCount = 3;

  final OrderRepository orders;
  final CartRepository cart;
  final SessionRepository session;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;
  final DateTime Function() _clock;

  late final Command1<int, Order> reorder;

  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'orders',
    onChanged: notifyListeners,
  );
  StreamSubscription<List<Order>>? _sub;
  ViewState<List<Order>> _state = const ViewLoading();

  ViewState<List<Order>> get state => _state;
  DateTime get now => _clock();

  List<Order> get _all => _state.dataOrNull ?? const [];

  List<Order> get active => _all.where(isActive).toList();

  List<Order> get finished => _all.where((o) => !isActive(o)).toList();

  List<Order> get recent => finished.take(recentCount).toList();

  static bool isActive(Order order) => order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled;

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _sub = orders
        .watchMyOrders(uid)
        .listen(
          (list) {
            final sorted = [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _state = ViewStateX.fromList(sorted, emptyMessage: emptyMessage);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'orders.watchMyOrders');
            _state = ViewError(error is AppException ? error.message : 'Không tải được đơn hàng.');
            notifyListeners();
          },
        );
  }

  String title(Order order) => isActive(order)
      ? '#${order.orderCode} · ${order.kioskName}'
      : '#${order.orderCode} · ${formatDate(order.createdAt)}';

  String timing(Order order) => switch (order.status) {
    OrderStatus.pending => 'Chờ kiosk nhận đơn',
    OrderStatus.preparing => switch (order.readyBy) {
      final readyBy? when readyBy.isAfter(now) =>
        'Sẵn sàng khoảng ${formatTime(readyBy)} (${formatTimeLeft(readyBy, now: now)})',
      _ => 'Kiosk đang làm món',
    },
    OrderStatus.ready => 'Đã sẵn sàng, mời bạn tới quầy',
    OrderStatus.delivered => 'Đã lấy món ${formatTime(order.deliveredAt ?? order.updatedAt ?? order.createdAt)}',
    OrderStatus.cancelled => 'Đã huỷ',
  };

  Future<Result<int>> _reorder(Order order) async {
    final result = await _cart.reorder(order);
    if (result is Ok<int>) await session.selectKiosk(order.kioskId);
    return result;
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    reorder.dispose();
    super.dispose();
  }
}
