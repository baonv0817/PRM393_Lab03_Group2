import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/queued_quantities.dart';
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
    _configSub = remoteConfig.watchUpdates().listen((_) {
      _applyQuickItems();
      notifyListeners();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'home.watchRemoteConfig'));
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

  late final addToCart = Command1<void, MenuItem>(_addToCart);

  late final reorderLast = Command0<int>(_reorderLast);

  StreamSubscription<List<MenuItem>>? _menuSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  StreamSubscription<String?>? _sessionSub;
  StreamSubscription<Cart>? _cartSub;
  StreamSubscription<List<Order>>? _ordersSub;
  late final StreamSubscription<Set<String>> _configSub;

  ViewState<List<MenuItem>> _state = const ViewLoading();
  List<MenuItem>? _menuItems;
  List<Kiosk>? _kiosks;
  String? _selectedKioskId;
  bool _sessionKnown = false;
  Kiosk? _kiosk;
  Cart _cart = Cart.empty;
  late final _quantities = QueuedQuantities(
    write: (id, quantity) => cart.setQuantity(uid, id, quantity),
    onChanged: notifyListeners,
  );
  Order? _lastOrder;

  ViewState<List<MenuItem>> get state => _state;

  bool get promoBannerEnabled => remoteConfig.getBool(RemoteKeys.promoBannerEnabled);

  Kiosk? get kiosk => _kiosk;

  String? get kioskStatus {
    final k = _kiosk;
    if (k == null) return null;
    if (!k.open) return 'Đang đóng cửa';
    final low = k.waitMinutes > 1 ? k.waitMinutes - 1 : 1;
    return 'Sẵn sàng · chờ $low–${k.waitMinutes + 1} phút';
  }

  int get cartCount {
    var total = 0;
    for (final line in _cart.items) {
      total += _quantities.pendingOf(line.itemId) ?? line.quantity;
    }
    return total;
  }

  int quantityOf(String itemId) => _quantities.pendingOf(itemId) ?? _storedQuantity(itemId);

  int _storedQuantity(String itemId) => _cart.items.where((line) => line.itemId == itemId).firstOrNull?.quantity ?? 0;

  bool canIncrease(String itemId) => quantityOf(itemId) < Cart.maxQuantity;

  bool blocksAdd(MenuItem item) => !_cart.isEmpty && _cart.kioskId != item.kioskId;

  int get unreadNotifications => 0;

  Order? get lastOrder => _lastOrder;

  void load() {
    _state = const ViewLoading();
    _menuItems = null;
    _kiosks = null;
    _sessionKnown = false;
    _kiosk = null;
    notifyListeners();
    _cancelSubscriptions();
    _kioskSub = menu.watchKiosks().listen((kiosks) {
      _kiosks = kiosks;
      _applyKiosk();
    }, onError: (Object e, StackTrace s) => _fail(e, s, 'home.watchKiosks'));
    _sessionSub = session.watchSelectedKioskId().listen((id) {
      _selectedKioskId = id;
      _sessionKnown = true;
      _applyKiosk();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'home.watchSelectedKiosk'));
    _cartSub = cart.watchCart(uid).listen((current) {
      _cart = current;
      _quantities.settle(_storedQuantity);
      notifyListeners();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'home.watchCart'));
    _ordersSub = orders.watchMyOrders(uid).listen((list) {
      final mine = list.where((o) => o.status != OrderStatus.cancelled).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _lastOrder = mine.firstOrNull;
      notifyListeners();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'home.watchMyOrders'));
  }

  void _cancelSubscriptions() {
    unawaited(_menuSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_sessionSub?.cancel());
    unawaited(_cartSub?.cancel());
    unawaited(_ordersSub?.cancel());
  }

  void _applyKiosk() {
    final kiosks = _kiosks;
    if (kiosks == null || !_sessionKnown) return;
    final chosen = kiosks.where((k) => k.id == _selectedKioskId).firstOrNull;
    final next = chosen ?? kiosks.where((k) => k.open).firstOrNull ?? kiosks.firstOrNull;
    if (chosen == null && next != null) unawaited(session.selectKiosk(next.id));
    final changed = next?.id != _kiosk?.id;
    _kiosk = next;
    if (next == null) {
      unawaited(_menuSub?.cancel());
      _menuItems = null;
      _state = const ViewEmpty('Chưa có kiosk nào đang hoạt động');
    } else if (changed) {
      _watchMenu(next.id);
    }
    notifyListeners();
  }

  void _watchMenu(String kioskId) {
    unawaited(_menuSub?.cancel());
    _menuItems = null;
    _state = const ViewLoading();
    _menuSub = menu.watchMenu(kioskId).listen((items) {
      _menuItems = items;
      _applyQuickItems();
      notifyListeners();
    }, onError: (Object e, StackTrace s) => _fail(e, s, 'home.watchMenu'));
  }

  void _applyQuickItems() {
    final items = _menuItems;
    if (items == null) return;
    final limit = remoteConfig.getInt(RemoteKeys.quickItemsLimit);
    final quick = items.where((e) => !e.soldOut && e.prepMinutes <= quickMaxMinutes).take(limit).toList();
    _state = ViewStateX.fromList(quick, emptyMessage: 'Chưa có món nhanh lúc này');
  }

  void _fail(Object error, StackTrace stack, String reason) {
    crash.recordNonFatal(error, stack, reason);
    _state = ViewError(error is AppException ? error.message : 'Không tải được thực đơn. Kiểm tra mạng rồi thử lại.');
    notifyListeners();
  }

  Future<Result<void>> _addToCart(MenuItem item) async {
    final result = await cart.addItem(
      uid,
      kioskId: item.kioskId,
      item: CartItem(itemId: item.id, name: item.name, priceVnd: item.priceVnd),
    );
    switch (result) {
      case Ok():
        await analytics.logEvent(AnalyticsEvents.addToCart, {'item_id': item.id, 'quantity': 1, 'source': 'home'});
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'home.addToCart');
    }
    return result;
  }

  Future<Result<void>> changeQuantity(MenuItem item, int delta) async {
    final current = quantityOf(item.id);
    final next = (current + delta).clamp(0, Cart.maxQuantity);
    if (next == current) return const Result.ok(null);
    if (delta > 0) {
      unawaited(analytics.logEvent(AnalyticsEvents.addToCart, {'item_id': item.id, 'quantity': 1, 'source': 'home'}));
    }
    final result = await _quantities.set(item.id, next);
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'home.changeQuantity');
    return result;
  }

  Future<Result<int>> _reorderLast() async {
    final order = _lastOrder;
    if (order == null) return const Result.ok(0);
    for (final item in order.items) {
      final result = await cart.addItem(uid, kioskId: order.kioskId, item: item);
      if (result case Err(:final error)) {
        crash.recordNonFatal(error, error.stackTrace, 'home.reorderLast');
        return Result.error(error);
      }
    }
    if (order.kioskId != _kiosk?.id) await session.selectKiosk(order.kioskId);
    await analytics.logEvent(AnalyticsEvents.reorder, {'order_id': order.id, 'item_count': order.items.length});
    return Result.ok(order.items.length);
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    unawaited(_configSub.cancel());
    addToCart.dispose();
    reorderLast.dispose();
    super.dispose();
  }
}
