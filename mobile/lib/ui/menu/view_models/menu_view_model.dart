import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite/ui/menu/view_models/kiosk_menu.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:breakbite_core/utils/text.dart';
import 'package:flutter/foundation.dart';

enum MenuFilter {
  all('Tất cả'),
  quick('Dưới 5 phút'),
  food('Món ăn'),
  drink('Đồ uống');

  const MenuFilter(this.label);

  final String label;
}

class MenuViewModel extends ChangeNotifier with SafeChangeNotifier {
  MenuViewModel({
    required this.menu,
    required this.cart,
    required this.session,
    required this.analytics,
    required this.crash,
    required this.uid,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    load();
  }

  static const quickMaxMinutes = 5;
  static const noMatchMessage = 'Không có món phù hợp';
  static const emptyMenuMessage = 'Kiosk này chưa có món nào';

  final MenuRepository menu;
  final CartRepository cart;
  final SessionRepository session;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;
  final DateTime Function() _clock;

  late final addToCart = Command1<void, MenuItem>(_cart.add);

  late final _menu = KioskMenu(menu: menu, session: session, crash: crash, reason: 'menu', onChanged: notifyListeners);
  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'menu',
    onChanged: notifyListeners,
  );

  String _query = '';
  MenuFilter _filter = MenuFilter.all;

  String get query => _query;
  MenuFilter get filter => _filter;
  bool get filtering => _query.trim().isNotEmpty || _filter != MenuFilter.all;

  Kiosk? get kiosk => _menu.kiosk;

  String? get kioskStatus {
    final k = kiosk;
    return k == null ? null : kioskStatusLabel(k, now: _clock());
  }

  ViewState<List<MenuItem>> get state =>
      _menu.stateOf(_pick, emptyMessage: filtering ? noMatchMessage : emptyMenuMessage);

  List<MenuItem> _pick(List<MenuItem> items) {
    final key = searchKey(_query.trim());
    final matches = items.where((item) {
      if (key.isNotEmpty && !searchKey(item.name).contains(key)) return false;
      return switch (_filter) {
        MenuFilter.all => true,
        MenuFilter.quick => item.prepMinutes <= quickMaxMinutes,
        MenuFilter.food => item.category == ItemCategory.food,
        MenuFilter.drink => item.category == ItemCategory.drink,
      };
    });
    return [...matches.where((e) => !e.soldOut), ...matches.where((e) => e.soldOut)];
  }

  int get cartCount => _cart.count;

  int quantityOf(String itemId) => _cart.quantityOf(itemId);

  bool canIncrease(String itemId) => _cart.canIncrease(itemId);

  bool blocksAdd(MenuItem item) => _cart.blocksAdd(item);

  void search(String query) {
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }

  void choose(MenuFilter filter) {
    _filter = filter == _filter ? MenuFilter.all : filter;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _filter = MenuFilter.all;
    notifyListeners();
  }

  void load() {
    _menu.start();
    _cart.start();
  }

  Future<Result<void>> changeQuantity(MenuItem item, int delta) => _cart.change(item, delta);

  @override
  void dispose() {
    _menu.stop();
    _cart.stop();
    addToCart.dispose();
    super.dispose();
  }
}
