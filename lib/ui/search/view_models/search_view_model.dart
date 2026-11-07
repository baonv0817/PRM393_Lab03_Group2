import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/menu/view_models/kiosk_menu.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:breakbite/utils/text.dart';
import 'package:flutter/foundation.dart';

enum SearchFilter {
  all('Tất cả'),
  food('Món ăn'),
  drink('Đồ uống');

  const SearchFilter(this.label);

  final String label;
}

/// S28 and S28-EMPTY: search the menu of the selected kiosk by name. Accents do not matter ("banh mi" finds
/// "Bánh mì"), the list filters 300 ms after the last key, and an empty result suggests other words.
class SearchViewModel extends ChangeNotifier with SafeChangeNotifier {
  SearchViewModel({
    required this.menu,
    required this.cart,
    required this.session,
    required this.analytics,
    required this.crash,
    required this.uid,
    this.debounce = const Duration(milliseconds: 300),
  }) {
    _cart.start();
    _kioskMenu.start();
  }

  /// Words offered when nothing matches (Figma "Gợi ý").
  static const suggestions = ['Tacos', 'Mì trộn', 'Trà đào'];

  final MenuRepository menu;
  final CartRepository cart;
  final SessionRepository session;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;
  final Duration debounce;

  late final _kioskMenu = KioskMenu(
    menu: menu,
    session: session,
    crash: crash,
    reason: 'search',
    onChanged: notifyListeners,
  );
  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'search',
    onChanged: notifyListeners,
  );

  Timer? _timer;
  var _typed = '';
  var _query = '';
  var _filter = SearchFilter.all;
  String? _loggedQuery;

  /// What is in the box now (it may be ahead of [query] by up to the debounce time).
  String get typed => _typed;

  /// What the list is filtered by.
  String get query => _query;

  SearchFilter get filter => _filter;

  Kiosk? get kiosk => _kioskMenu.kiosk;

  bool get closed => kiosk?.acceptsOrders(DateTime.now()) == false;

  int get cartCount => _cart.count;

  bool blocksAdd(MenuItem item) => _cart.blocksAdd(item);

  int quantityOf(MenuItem item) => _cart.quantityOf(item.id);

  bool canIncrease(MenuItem item) => _cart.canIncrease(item.id);

  bool get searching => _query.isNotEmpty;

  /// Before anything is typed there is nothing to list; then the matches, or an empty state with suggestions.
  ViewState<List<MenuItem>> get state => _kioskMenu.stateOf(
    (items) => searching ? _matches(items) : const [],
    emptyMessage: searching ? 'Không tìm thấy "$_query"' : '',
  );

  /// How many items match; `null` while loading or before anything is typed.
  int? get resultCount {
    if (!searching) return null;
    return switch (state) {
      ViewData(:final data) => data.length,
      ViewEmpty(:final message) when message != KioskMenu.noKioskMessage => 0,
      _ => null,
    };
  }

  List<MenuItem> _matches(List<MenuItem> items) {
    final key = searchKey(_query);
    final hits = items.where((item) {
      final inFilter = switch (_filter) {
        SearchFilter.all => true,
        SearchFilter.food => item.category == ItemCategory.food,
        SearchFilter.drink => item.category == ItemCategory.drink,
      };
      return inFilter && searchKey(item.name).contains(key);
    }).toList();
    // In stock first; the stock order inside each group is the menu's own.
    return [...hits.where((i) => !i.soldOut), ...hits.where((i) => i.soldOut)];
  }

  void retry() => _kioskMenu.start();

  /// Called on every key: the list follows after the debounce time, a blank box clears it at once.
  void setQuery(String value) {
    _typed = value;
    _timer?.cancel();
    if (value.trim().isEmpty) {
      _apply('');
      return;
    }
    _timer = Timer(debounce, () => _apply(value.trim()));
    notifyListeners();
  }

  /// Searches [value] now (a suggestion chip or the keyboard's search key).
  void searchNow(String value) {
    _typed = value;
    _timer?.cancel();
    _apply(value.trim());
  }

  void _apply(String value) {
    _query = value;
    notifyListeners();
    if (value.isNotEmpty && value != _loggedQuery) {
      _loggedQuery = value;
      unawaited(analytics.logEvent(AnalyticsEvents.search, {'search_term': value, 'result_count': resultCount ?? 0}));
    }
  }

  void setFilter(SearchFilter value) {
    if (value == _filter) return;
    _filter = value;
    notifyListeners();
  }

  Future<Result<void>> addToCart(MenuItem item) => _cart.add(item);

  Future<Result<void>> changeQuantity(MenuItem item, int delta) => _cart.change(item, delta);

  @override
  void dispose() {
    _timer?.cancel();
    _kioskMenu.stop();
    _cart.stop();
    super.dispose();
  }
}
