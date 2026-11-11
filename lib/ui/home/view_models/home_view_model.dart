import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/menu/view_models/kiosk_menu.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

class HomeViewModel extends ChangeNotifier with SafeChangeNotifier {
  HomeViewModel({
    required this.menu,
    required this.cart,
    required this.orders,
    required this.session,
    required this.remoteConfig,
    required this.analytics,
    required this.crash,
    required this.uid,
    this.notifications,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    load();
    _watchUnread();
    _configSub = remoteConfig.watchUpdates().listen(
      (_) => notifyListeners(),
      onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'home.watchRemoteConfig'),
    );
  }

  final MenuRepository menu;
  final CartRepository cart;
  final OrderRepository orders;
  final SessionRepository session;
  final RemoteConfigService remoteConfig;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;

  /// The inbox behind the bell; without it the bell never shows a dot.
  final NotificationRepository? notifications;
  final DateTime Function() _clock;

  static const quickMaxMinutes = 5;
  static const quickEmptyMessage = 'Chưa có món nhanh lúc này';
  static const previewEmptyMessage = 'Quán chưa có món để xem trước';

  late final addToCart = Command1<void, MenuItem>(_cart.add);

  late final reorderLast = Command0<int>(_reorderLast);

  late final _menu = KioskMenu(menu: menu, session: session, crash: crash, reason: 'home', onChanged: _menuChanged);
  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'home',
    onChanged: notifyListeners,
  );
  StreamSubscription<List<Order>>? _ordersSub;
  StreamSubscription<List<AppNotification>>? _unreadSub;
  var _unread = 0;
  late final StreamSubscription<Set<String>> _configSub;
  Timer? _pauseEnd;
  Order? _lastOrder;

  /// The quick items, or while the kiosk takes no orders (S21) a preview of its menu.
  ViewState<List<MenuItem>> get state {
    final limit = remoteConfig.getInt(RemoteKeys.quickItemsLimit);
    if (closed) {
      return _menu.stateOf(
        (items) => items.where((e) => !e.soldOut).take(limit).toList(),
        emptyMessage: previewEmptyMessage,
      );
    }
    return _menu.stateOf(
      (items) => items.where((e) => !e.soldOut && e.prepMinutes <= quickMaxMinutes).take(limit).toList(),
      emptyMessage: quickEmptyMessage,
    );
  }

  bool get promoBannerEnabled => remoteConfig.getBool(RemoteKeys.promoBannerEnabled);

  Kiosk? get kiosk => _menu.kiosk;

  /// S21: the kiosk is closed or paused, so the rules would reject an order.
  bool get closed => kiosk?.acceptsOrders(_clock()) == false;

  String get closedTitle {
    final k = kiosk;
    final shut = k != null && (!k.open || !k.isWithinHours(_clock()));
    return shut ? 'Quán đang đóng cửa' : 'Quán tạm ngưng nhận đơn';
  }

  /// When it takes orders again: "Mở lại lúc 07:00", "Nhận đơn lại lúc 10:15", or null without opening hours.
  String? get reopenLabel {
    final k = kiosk;
    if (k == null || !closed) return null;
    if (!k.open || !k.isWithinHours(_clock())) return k.openTime == null ? null : 'Mở lại lúc ${k.openTime}';
    return 'Nhận đơn lại lúc ${formatTime(k.pausedUntil!)}';
  }

  String get closedMessage {
    final notice = kiosk?.notice?.trim() ?? '';
    final reopen = reopenLabel;
    return [
      if (notice.isNotEmpty) notice.endsWith('.') ? notice : '$notice.',
      if (reopen != null) '$reopen.',
      'Bạn xem trước thực đơn được, hoặc chọn kiosk khác để đặt món ngay.',
    ].join(' ');
  }

  String? get kioskStatus {
    final k = kiosk;
    if (k == null) return null;
    if (closed) return kioskStatusLabel(k, now: _clock());
    final low = k.waitMinutes > 1 ? k.waitMinutes - 1 : 1;
    return 'Sẵn sàng · chờ $low–${k.waitMinutes + 1} phút';
  }

  int get cartCount => _cart.count;

  int quantityOf(String itemId) => _cart.quantityOf(itemId);

  bool canIncrease(String itemId) => _cart.canIncrease(itemId);

  bool blocksAdd(MenuItem item) => _cart.blocksAdd(item);

  int get unreadNotifications => _unread;

  void _watchUnread() {
    _unreadSub = notifications?.watch(uid).listen(
      (list) {
        final count = list.where((n) => !n.read).length;
        if (count == _unread) return;
        _unread = count;
        notifyListeners();
      },
      // The bell is an extra: a failure leaves it without a dot, it does not break Home.
      onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'home.watchNotifications'),
    );
  }

  Order? get lastOrder => _lastOrder;

  void load() {
    _menu.start();
    _cart.start();
    unawaited(_ordersSub?.cancel());
    _ordersSub = orders.watchMyOrders(uid).listen((list) {
      final mine = list.where((o) => o.status != OrderStatus.cancelled).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _lastOrder = mine.firstOrNull;
      notifyListeners();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'home.watchMyOrders'));
  }

  Future<Result<void>> changeQuantity(MenuItem item, int delta) => _cart.change(item, delta);

  // A pause ends on its own, so wake up then to bring back the normal Home.
  void _menuChanged() {
    _pauseEnd?.cancel();
    final until = kiosk?.pausedUntil;
    if (kiosk?.open ?? false) {
      final left = until?.difference(_clock()) ?? Duration.zero;
      if (left > Duration.zero) _pauseEnd = Timer(left, notifyListeners);
    }
    notifyListeners();
  }

  Future<Result<int>> _reorderLast() async {
    final order = _lastOrder;
    if (order == null) return const Result.ok(0);
    final result = await _cart.reorder(order);
    if (result is Ok<int> && order.kioskId != kiosk?.id) await session.selectKiosk(order.kioskId);
    return result;
  }

  @override
  void dispose() {
    _menu.stop();
    _cart.stop();
    unawaited(_ordersSub?.cancel());
    unawaited(_unreadSub?.cancel());
    unawaited(_configSub.cancel());
    _pauseEnd?.cancel();
    addToCart.dispose();
    reorderLast.dispose();
    super.dispose();
  }
}
