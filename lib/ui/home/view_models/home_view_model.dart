import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// Reference ViewModel for a data-loading screen (S02 Home), with loading, empty, error and data.
/// The "quick items" filter, the Remote Config limit, kiosk status, cart count and the latest
/// order (for reorder) live here, not in `build()`. User actions are [Command]s.
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
  }

  final MenuRepository menu;
  final CartRepository cart;
  final OrderRepository orders;
  final SessionRepository session;
  final RemoteConfigService remoteConfig;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;

  /// Items prepared in at most this many minutes count as "quick" (Lab 2: a 15-minute break).
  static const quickMaxMinutes = 5;

  /// Adds one portion of an item to the cart (the + button).
  late final addToCart = Command1<void, MenuItem>(_addToCart);

  /// Adds the lines of the latest order back to the cart; the value is the number of lines added
  /// (0 when there is no order yet).
  late final reorderLast = Command0<int>(_reorderLast);

  StreamSubscription<List<MenuItem>>? _menuSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  StreamSubscription<String?>? _sessionSub;
  StreamSubscription<List<CartItem>>? _cartSub;
  StreamSubscription<List<Order>>? _ordersSub;

  ViewState<List<MenuItem>> _state = const ViewLoading();
  List<Kiosk>? _kiosks;
  String? _selectedKioskId;
  bool _sessionKnown = false;
  Kiosk? _kiosk;
  int _cartCount = 0;
  Order? _lastOrder;

  /// The quick items.
  ViewState<List<MenuItem>> get state => _state;

  bool get promoBannerEnabled => remoteConfig.getBool(RemoteKeys.promoBannerEnabled);

  /// Kiosk being ordered from: the one chosen in the session (S27), otherwise the first open kiosk,
  /// which then becomes the session's choice.
  Kiosk? get kiosk => _kiosk;

  /// Status line under the kiosk name, for example "Sẵn sàng · chờ 5–7 phút".
  String? get kioskStatus {
    final k = _kiosk;
    if (k == null) return null;
    if (!k.open) return 'Đang đóng cửa';
    final low = k.waitMinutes > 1 ? k.waitMinutes - 1 : 1;
    return 'Sẵn sàng · chờ $low–${k.waitMinutes + 1} phút';
  }

  /// Total portions in the cart (quantities summed), shown on the cart badge.
  int get cartCount => _cartCount;

  /// Unread notifications. There is no notification service yet (S19), so always 0.
  int get unreadNotifications => 0;

  /// Latest order that is not cancelled; `null` before the first order (the Reorder card is hidden).
  Order? get lastOrder => _lastOrder;

  void load() {
    _state = const ViewLoading();
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
    }, onError: (Object e, StackTrace s) => _log(e, s, 'home.watchSelectedKiosk'));
    _cartSub = cart.watchCart(uid).listen((items) {
      _cartCount = items.fold(0, (sum, e) => sum + e.quantity);
      notifyListeners();
    }, onError: (Object e, StackTrace s) => _log(e, s, 'home.watchCart'));
    _ordersSub = orders.watchMyOrders(uid).listen((list) {
      final mine = list.where((o) => o.status != OrderStatus.cancelled).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _lastOrder = mine.firstOrNull;
      notifyListeners();
    }, onError: (Object e, StackTrace s) => _log(e, s, 'home.watchMyOrders'));
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
      _state = const ViewEmpty('Chưa có kiosk nào đang hoạt động');
    } else if (changed) {
      _watchMenu(next.id);
    }
    notifyListeners();
  }

  void _watchMenu(String kioskId) {
    unawaited(_menuSub?.cancel());
    _state = const ViewLoading();
    _menuSub = menu.watchMenu(kioskId).listen((items) {
      final limit = remoteConfig.getInt(RemoteKeys.quickItemsLimit);
      final quick = items.where((e) => !e.soldOut && e.prepMinutes <= quickMaxMinutes).take(limit).toList();
      _state = ViewStateX.fromList(quick, emptyMessage: 'Chưa có món nhanh lúc này');
      notifyListeners();
    }, onError: (Object e, StackTrace s) => _fail(e, s, 'home.watchMenu'));
  }

  void _fail(Object error, StackTrace stack, String reason) {
    _log(error, stack, reason);
    _state = const ViewError('Không tải được thực đơn. Kiểm tra mạng rồi thử lại.');
    notifyListeners();
  }

  /// The cart badge and the Reorder card only add to the page: their errors are logged as
  /// non-fatal and do not block the item list.
  void _log(Object error, StackTrace stack, String reason) =>
      unawaited(crash.recordError(error, stack, reason: reason));

  Future<Result<void>> _addToCart(MenuItem item) async {
    final result = await cart.addItem(uid, CartItem(itemId: item.id, name: item.name, priceVnd: item.priceVnd));
    switch (result) {
      case Ok():
        await analytics.logEvent(AnalyticsEvents.addToCart, {'item_id': item.id, 'quantity': 1, 'source': 'home'});
      case Err(:final error):
        _log(error.cause ?? error, error.stackTrace ?? StackTrace.current, 'home.addToCart');
    }
    return result;
  }

  Future<Result<int>> _reorderLast() async {
    final order = _lastOrder;
    if (order == null) return const Result.ok(0);
    for (final item in order.items) {
      final result = await cart.addItem(uid, item);
      if (result case Err(:final error)) {
        _log(error.cause ?? error, error.stackTrace ?? StackTrace.current, 'home.reorderLast');
        return Result.error(error);
      }
    }
    await analytics.logEvent(AnalyticsEvents.reorder, {'order_id': order.id, 'item_count': order.items.length});
    return Result.ok(order.items.length);
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    addToCart.dispose();
    reorderLast.dispose();
    super.dispose();
  }
}
