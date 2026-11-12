import 'dart:async';

import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite/ui/menu/view_models/kiosk_menu.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// One row of S13: a hearted dish and, when the selected kiosk sells it, today's menu item (the price and
/// whether it is in stock come from there, not from the favorite).
class FavoriteEntry {
  const FavoriteEntry({required this.favorite, this.item, this.orderedTimes = 0});

  final Favorite favorite;
  final MenuItem? item;

  /// How many times the customer has ordered the dish, counted from their orders.
  final int orderedTimes;

  bool get available => item != null && !item!.soldOut;
}

enum FavoritesFilter {
  all('Tất cả'),
  food('Món ăn'),
  drink('Đồ uống');

  const FavoritesFilter(this.label);

  final String label;
}

/// S13: the dishes the customer hearted, filtered by kind, with one tap to put one in the cart.
class FavoritesViewModel extends ChangeNotifier with SafeChangeNotifier {
  FavoritesViewModel({
    required this.favorites,
    required this.menu,
    required this.cart,
    required this.orders,
    required this.session,
    required this.analytics,
    required this.crash,
    required this.uid,
  }) {
    load();
  }

  static const emptyMessage = 'Bạn chưa có món yêu thích. Chạm trái tim ở trang món để lưu lại.';

  final FavoriteRepository favorites;
  final MenuRepository menu;
  final CartRepository cart;
  final OrderRepository orders;
  final SessionRepository session;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;

  late final _kioskMenu = KioskMenu(
    menu: menu,
    session: session,
    crash: crash,
    reason: 'favorites',
    onChanged: notifyListeners,
  );
  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'favorites',
    onChanged: notifyListeners,
  );

  StreamSubscription<List<Favorite>>? _favoritesSub;
  StreamSubscription<List<Order>>? _ordersSub;
  List<Favorite>? _favorites;
  String? _error;
  var _times = <String, int>{};
  var _filter = FavoritesFilter.all;

  FavoritesFilter get filter => _filter;

  Kiosk? get kiosk => _kioskMenu.kiosk;

  int get cartCount => _cart.count;

  bool blocksAdd(MenuItem item) => _cart.blocksAdd(item);

  int quantityOf(MenuItem item) => _cart.quantityOf(item.id);

  bool canIncrease(MenuItem item) => _cart.canIncrease(item.id);

  List<FavoriteEntry> get _entries {
    final items = _kioskMenu.items ?? const <MenuItem>[];
    return [
      for (final favorite in _favorites ?? const <Favorite>[])
        FavoriteEntry(
          favorite: favorite,
          item: items.where(favorite.matches).firstOrNull,
          orderedTimes: _times[favorite.dishId] ?? 0,
        ),
    ];
  }

  bool _inFilter(FavoriteEntry entry) {
    final category = entry.item?.category ?? entry.favorite.category;
    return switch (_filter) {
      FavoritesFilter.all => true,
      FavoritesFilter.food => category == ItemCategory.food,
      FavoritesFilter.drink => category == ItemCategory.drink,
    };
  }

  /// The favorites of the chosen kind: dishes on sale first, then the ones this kiosk does not have or has
  /// sold out; inside each group the one hearted last first.
  ViewState<List<FavoriteEntry>> get state {
    if (_error case final message?) return ViewError(message);
    if (_favorites == null) return const ViewLoading();
    if (_favorites!.isEmpty) return const ViewEmpty(emptyMessage);
    final shown = _entries.where(_inFilter).toList();
    if (shown.isEmpty) return ViewEmpty('Chưa có ${_filter.label.toLowerCase()} yêu thích.');
    final onSale = shown.where((e) => e.available);
    final rest = shown.where((e) => !e.available);
    return ViewData([...onSale, ...rest]);
  }

  void setFilter(FavoritesFilter value) {
    if (value == _filter) return;
    _filter = value;
    notifyListeners();
  }

  void load() {
    unawaited(_favoritesSub?.cancel());
    unawaited(_ordersSub?.cancel());
    _favorites = null;
    _error = null;
    notifyListeners();
    _cart.start();
    _kioskMenu.start();
    _favoritesSub = favorites
        .watch(uid)
        .listen(
          (list) {
            _favorites = list;
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'favorites.watch');
            _error = error is AppException ? error.message : 'Không tải được món yêu thích.';
            notifyListeners();
          },
        );
    // "Đã đặt N lần" is an extra: when it cannot be counted the rows simply do not show it.
    _ordersSub = orders
        .watchMyOrders(uid, limit: 50)
        .listen(
          (list) => unawaited(_countTimes(list)),
          onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'favorites.watchOrders'),
        );
  }

  /// Counts the portions of each dish in the delivered orders. A line only knows its menu item id, so the
  /// dish comes from that menu item (the id alone only works when it is `<kioskId>-<dishId>`).
  Future<void> _countTimes(List<Order> list) async {
    final delivered = list.where((o) => o.status == OrderStatus.delivered).toList();
    final ids = {
      for (final o in delivered)
        for (final line in o.items) line.itemId,
    };
    var known = const <String, MenuItem>{};
    if (ids.isNotEmpty) {
      switch (await menu.getItems(ids)) {
        case Ok(:final value):
          known = value;
        case Err(:final error):
          crash.recordNonFatal(error, error.stackTrace, 'favorites.getItems');
      }
    }
    final times = <String, int>{};
    for (final order in delivered) {
      for (final line in order.items) {
        final item = known[line.itemId];
        final id = item != null ? Favorite.dishIdOf(item) : ReviewRepository.dishIdOf(order.kioskId, line.itemId);
        times[id] = (times[id] ?? 0) + line.quantity;
      }
    }
    _times = times;
    notifyListeners();
  }

  Future<Result<void>> addToCart(MenuItem item) => _cart.add(item);

  Future<Result<void>> changeQuantity(MenuItem item, int delta) => _cart.change(item, delta);

  /// Takes the heart off a dish. The row goes away at once because the list follows the stored favorites.
  Future<Result<void>> remove(Favorite favorite) async {
    final result = await favorites.remove(uid, favorite.dishId);
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'favorites.remove');
    return result;
  }

  @override
  void dispose() {
    unawaited(_favoritesSub?.cancel());
    unawaited(_ordersSub?.cancel());
    _kioskMenu.stop();
    _cart.stop();
    super.dispose();
  }
}
