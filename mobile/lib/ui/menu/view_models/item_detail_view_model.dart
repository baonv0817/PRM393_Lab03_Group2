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

class ItemDetailViewModel extends ChangeNotifier with SafeChangeNotifier {
  ItemDetailViewModel({
    required this.menu,
    required this.cart,
    required this.analytics,
    required this.crash,
    required this.uid,
    required this.itemId,
    this.favorites,
  }) {
    add = Command0(_add);
    _cart.start();
    load();
    _watchFavorites();
  }

  static const maxNoteLength = 100;
  static const otherKioskMessage = 'Giỏ đang có món của kiosk khác. Đặt xong hoặc xoá giỏ để thêm món này.';

  final MenuRepository menu;
  final CartRepository cart;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;
  final String itemId;

  /// The hearts of S13. Without it the heart of S04 is not shown.
  final FavoriteRepository? favorites;

  late final Command0<void> add;

  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'detail',
    onChanged: notifyListeners,
  );

  StreamSubscription<List<Favorite>>? _favoritesSub;
  List<Favorite> _hearts = const [];
  bool _togglingFavorite = false;
  ViewState<MenuItem> _state = const ViewLoading();
  bool _viewLogged = false;
  int _quantity = 1;
  String _note = '';

  /// What the customer picked, by group id: the choice ids.
  final Map<String, Set<String>> _picked = {};

  ViewState<MenuItem> get state => _state;
  MenuItem? get item => _state.dataOrNull;
  int get quantity => _quantity;
  String get note => _note;
  int get inCart => _cart.quantityOf(itemId);

  /// The line this opening would add to: the dish with the choices picked now.
  String get _lineKey => item == null ? itemId : _line(1).lineKey;
  int get _room => _cart.roomForLine(_lineKey);

  CartItem _line(int quantity) {
    final i = item!;
    final options = i.choicesFor(_picked);
    return CartItem(
      itemId: i.id,
      name: i.name,
      priceVnd: i.priceWith(_picked),
      quantity: quantity,
      note: _note.trim(),
      options: options,
    );
  }

  Set<String> pickedIn(String groupId) => _picked[groupId] ?? const {};

  /// What staff still have to be told: the first group that is required and empty, or too full; `null` when the
  /// dish can be added.
  String? get optionsProblem => item?.optionsProblem(_picked);

  /// The price of one portion with the choices picked now.
  int get unitPriceVnd => item?.priceWith(_picked) ?? 0;

  /// Picks or drops a choice. A single-choice group switches to the new choice (and a group that is not required
  /// lets the customer tap it again to clear it); a multiple-choice group adds up to its maximum.
  void pick(OptionGroup group, String choiceId) {
    final now = {...pickedIn(group.id)};
    if (group.multiple) {
      if (!now.remove(choiceId)) {
        if (now.length >= group.maxChoices) return;
        now.add(choiceId);
      }
    } else if (now.contains(choiceId)) {
      if (group.required) return;
      now.clear();
    } else {
      now
        ..clear()
        ..add(choiceId);
    }
    _picked[group.id] = now;
    // The same dish with other choices is another line, so how many fit in the cart changes.
    _quantity = _quantity.clamp(1, _room < 1 ? 1 : _room);
    notifyListeners();
  }

  bool get canIncrease => _quantity < _room;
  bool get canDecrease => _quantity > 1;

  /// The heart of S04 is offered once the item has loaded and the hearts can be read.
  bool get canFavorite => favorites != null && item != null;

  /// Whether the dish of this item is one of the customer's favorites.
  bool get isFavorite {
    final i = item;
    return i != null && _hearts.any((f) => f.matches(i));
  }

  void _watchFavorites() {
    _favoritesSub = favorites?.watch(uid).listen(
      (list) {
        _hearts = list;
        notifyListeners();
      },
      // The heart is an extra: a failure leaves it empty, it does not break the item.
      onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'detail.watchFavorites'),
    );
  }

  /// Hearts the dish, or takes the heart off. One write at a time; the heart follows the stored favorites.
  Future<Result<void>> toggleFavorite() async {
    final i = item;
    final repository = favorites;
    if (i == null || repository == null || _togglingFavorite) return const Result.ok(null);
    _togglingFavorite = true;
    try {
      final result = isFavorite ? await repository.remove(uid, Favorite.dishIdOf(i)) : await repository.add(uid, i);
      if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'detail.toggleFavorite');
      return result;
    } finally {
      _togglingFavorite = false;
    }
  }

  String? get blocker {
    final i = item;
    if (i == null) return null;
    if (i.soldOut) {
      final again = i.availableAgainAt;
      return again == null ? 'Món này đang tạm hết.' : 'Món này đang tạm hết, có lại lúc ${formatTime(again)}.';
    }
    if (_cart.blocksAdd(i)) return otherKioskMessage;
    if (_room <= 0) return 'Giỏ đã có tối đa ${Cart.maxQuantity} phần món này.';
    return null;
  }

  bool get canAdd => item != null && blocker == null && optionsProblem == null && !add.running;

  String get addLabel {
    final i = item;
    return i == null ? 'Thêm vào giỏ' : 'Thêm vào giỏ · ${formatVnd(unitPriceVnd * _quantity)}';
  }

  Future<void> load() async {
    _state = const ViewLoading();
    notifyListeners();
    final result = await menu.getItem(itemId);
    switch (result) {
      case Ok(:final value):
        _state = ViewData(value);
        _preselect(value);
        _logView(value);
      case Err(error: NotFoundException(:final message)):
        _state = ViewEmpty(message);
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'detail.load');
        _state = ViewError(error.message);
    }
    notifyListeners();
  }

  /// A group that must have an answer and offers one choice at a time starts on its first choice, as the usual
  /// default (size M): the customer changes it instead of having to find it. Only on the first load.
  void _preselect(MenuItem item) {
    if (_picked.isNotEmpty) return;
    for (final group in item.optionGroups) {
      if (group.required && !group.multiple && group.choices.isNotEmpty) {
        _picked[group.id] = {group.choices.first.id};
      }
    }
  }

  /// `view_menu_item` once per opening of S04, not again on a retry or refresh.
  void _logView(MenuItem item) {
    if (_viewLogged) return;
    _viewLogged = true;
    unawaited(
      analytics.logEvent(AnalyticsEvents.viewMenuItem, {
        'item_id': item.id,
        'item_name': item.name,
        'category': item.category.name,
      }),
    );
  }

  void changeQuantity(int delta) {
    final next = (_quantity + delta).clamp(1, _room < 1 ? 1 : _room);
    if (next == _quantity) return;
    _quantity = next;
    notifyListeners();
  }

  void setNote(String value) {
    _note = value.length > maxNoteLength ? value.substring(0, maxNoteLength) : value;
  }

  Future<Result<void>> _add() async {
    final i = item;
    if (i == null) return const Result.error(NotFoundException(message: 'Không tìm thấy món.'));
    if (blocker case final message?) return Result.error(ValidationException(message));
    if (optionsProblem case final message?) return Result.error(ValidationException(message));
    return _cart.add(i, quantity: _quantity, note: _note.trim(), options: i.choicesFor(_picked));
  }

  @override
  void dispose() {
    unawaited(_favoritesSub?.cancel());
    _cart.stop();
    add.dispose();
    super.dispose();
  }
}
