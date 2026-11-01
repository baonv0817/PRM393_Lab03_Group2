import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/menu/view_models/kiosk_menu.dart';
import 'package:breakbite/utils/command.dart';
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
  }) {
    load();
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

  static const quickMaxMinutes = 5;
  static const quickEmptyMessage = 'Chưa có món nhanh lúc này';

  late final addToCart = Command1<void, MenuItem>(_cart.add);

  late final reorderLast = Command0<int>(_reorderLast);

  late final _menu = KioskMenu(menu: menu, session: session, crash: crash, reason: 'home', onChanged: notifyListeners);
  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'home',
    onChanged: notifyListeners,
  );
  StreamSubscription<List<Order>>? _ordersSub;
  late final StreamSubscription<Set<String>> _configSub;
  Order? _lastOrder;

  ViewState<List<MenuItem>> get state => _menu.stateOf((items) {
    final limit = remoteConfig.getInt(RemoteKeys.quickItemsLimit);
    return items.where((e) => !e.soldOut && e.prepMinutes <= quickMaxMinutes).take(limit).toList();
  }, emptyMessage: quickEmptyMessage);

  bool get promoBannerEnabled => remoteConfig.getBool(RemoteKeys.promoBannerEnabled);

  Kiosk? get kiosk => _menu.kiosk;

  String? get kioskStatus {
    final k = kiosk;
    if (k == null) return null;
    if (!k.open) return 'Đang đóng cửa';
    final low = k.waitMinutes > 1 ? k.waitMinutes - 1 : 1;
    return 'Sẵn sàng · chờ $low–${k.waitMinutes + 1} phút';
  }

  int get cartCount => _cart.count;

  int quantityOf(String itemId) => _cart.quantityOf(itemId);

  bool canIncrease(String itemId) => _cart.canIncrease(itemId);

  bool blocksAdd(MenuItem item) => _cart.blocksAdd(item);

  int get unreadNotifications => 0;

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
    unawaited(_configSub.cancel());
    addToCart.dispose();
    reorderLast.dispose();
    super.dispose();
  }
}
