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

/// What S22 shows: the item that is (or was) sold out, and the items of the same kiosk that can take its place.
class AlternativesData {
  const AlternativesData({required this.item, required this.suggestions});

  final MenuItem item;

  /// In stock, same category as [item], at most [AlternativesViewModel.maxSuggestions], the closest first.
  final List<MenuItem> suggestions;
}

/// S22 "Món tạm hết": tells the customer when a sold-out item is back and offers items that are in stock.
/// It follows the kiosk's menu live, so a suggestion that sells out disappears and the item itself may come back
/// while the customer is looking at the screen.
class AlternativesViewModel extends ChangeNotifier with SafeChangeNotifier {
  AlternativesViewModel({
    required this.menu,
    required this.cart,
    required this.analytics,
    required this.crash,
    required this.uid,
    required this.itemId,
  }) {
    _cart.start();
    load();
  }

  /// Lab 2 S22 shows two suggestions.
  static const maxSuggestions = 2;
  static const itemGoneMessage = 'Món này không còn trong thực đơn.';
  static const loadErrorMessage = 'Không tải được thực đơn. Kiểm tra mạng rồi thử lại.';
  static const noSuggestionsMessage = 'Hiện chưa có món thay thế còn hàng cùng loại.';

  final MenuRepository menu;
  final CartRepository cart;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;

  /// The sold-out item this screen is about.
  final String itemId;

  late final addToCart = Command1<void, MenuItem>(_cart.add);

  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'alternatives',
    onChanged: notifyListeners,
  );

  ViewState<AlternativesData> _state = const ViewLoading();
  StreamSubscription<List<MenuItem>>? _menuSub;

  ViewState<AlternativesData> get state => _state;

  /// The app bar title: the item may be back while the customer looks at the screen.
  String get title => switch (_state) {
    ViewData<AlternativesData>(:final data) when !data.item.soldOut => 'Món đã có lại',
    _ => 'Món tạm hết',
  };

  /// The line under the sold-out card: when it is back, or that it is already back.
  static String availabilityMessage(MenuItem item) {
    if (!item.soldOut) return 'Món này đã có lại, bạn có thể đặt ngay.';
    final again = item.availableAgainAt;
    return again == null ? 'Chưa có giờ bán lại' : 'Có lại lúc ${formatTime(again)}';
  }

  /// The items that can take the place of [item]: in stock, same category, the closest in preparation time first,
  /// then in price. Only items of [menu] (one kiosk) are offered, because a cart belongs to one kiosk.
  static List<MenuItem> suggest(MenuItem item, Iterable<MenuItem> menu) {
    final candidates = menu.where((e) => e.id != item.id && !e.soldOut && e.category == item.category).toList()
      ..sort((a, b) {
        final byTime = (a.prepMinutes - item.prepMinutes).abs().compareTo((b.prepMinutes - item.prepMinutes).abs());
        if (byTime != 0) return byTime;
        final byPrice = (a.priceVnd - item.priceVnd).abs().compareTo((b.priceVnd - item.priceVnd).abs());
        return byPrice != 0 ? byPrice : a.name.compareTo(b.name);
      });
    return candidates.take(maxSuggestions).toList();
  }

  int get cartCount => _cart.count;

  int quantityOf(String itemId) => _cart.quantityOf(itemId);

  bool canIncrease(String itemId) => _cart.canIncrease(itemId);

  bool blocksAdd(MenuItem item) => _cart.blocksAdd(item);

  Future<void> load() async {
    unawaited(_menuSub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    final result = await menu.getItem(itemId);
    if (isDisposed) return;
    switch (result) {
      case Ok(:final value):
        _watch(value.kioskId);
      case Err(error: NotFoundException(:final message)):
        _state = ViewEmpty<AlternativesData>(message);
        notifyListeners();
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'alternatives.load');
        _state = ViewError<AlternativesData>(error.message);
        notifyListeners();
    }
  }

  void _watch(String kioskId) {
    unawaited(_menuSub?.cancel());
    _menuSub = menu
        .watchMenu(kioskId)
        .listen(
          (items) {
            final current = items.where((e) => e.id == itemId).firstOrNull;
            _state = current == null
                ? const ViewEmpty<AlternativesData>(itemGoneMessage)
                : ViewData<AlternativesData>(AlternativesData(item: current, suggestions: suggest(current, items)));
            notifyListeners();
          },
          onError: (Object e, StackTrace s) {
            crash.recordNonFatal(e, s, 'alternatives.watchMenu');
            _state = ViewError<AlternativesData>(e is AppException ? e.message : loadErrorMessage);
            notifyListeners();
          },
        );
  }

  Future<Result<void>> changeQuantity(MenuItem item, int delta) => _cart.change(item, delta);

  @override
  void dispose() {
    unawaited(_menuSub?.cancel());
    _cart.stop();
    addToCart.dispose();
    super.dispose();
  }
}
