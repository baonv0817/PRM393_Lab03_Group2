import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

class ItemDetailViewModel extends ChangeNotifier with SafeChangeNotifier {
  ItemDetailViewModel({
    required this.menu,
    required this.cart,
    required this.analytics,
    required this.crash,
    required this.uid,
    required this.itemId,
  }) {
    add = Command0(_add);
    _cart.start();
    load();
  }

  static const maxNoteLength = 100;
  static const otherKioskMessage = 'Giỏ đang có món của kiosk khác. Đặt xong hoặc xoá giỏ để thêm món này.';

  final MenuRepository menu;
  final CartRepository cart;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;
  final String itemId;

  late final Command0<void> add;

  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'detail',
    onChanged: notifyListeners,
  );

  ViewState<MenuItem> _state = const ViewLoading();
  int _quantity = 1;
  String _note = '';

  ViewState<MenuItem> get state => _state;
  MenuItem? get item => _state.dataOrNull;
  int get quantity => _quantity;
  String get note => _note;
  int get inCart => _cart.quantityOf(itemId);
  int get _room => _cart.roomFor(itemId);

  bool get canIncrease => _quantity < _room;
  bool get canDecrease => _quantity > 1;

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

  bool get canAdd => item != null && blocker == null && !add.running;

  String get addLabel {
    final i = item;
    return i == null ? 'Thêm vào giỏ' : 'Thêm vào giỏ · ${formatVnd(i.priceVnd * _quantity)}';
  }

  Future<void> load() async {
    _state = const ViewLoading();
    notifyListeners();
    final result = await menu.getItem(itemId);
    switch (result) {
      case Ok(:final value):
        _state = ViewData(value);
      case Err(error: NotFoundException(:final message)):
        _state = ViewEmpty(message);
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'detail.load');
        _state = ViewError(error.message);
    }
    notifyListeners();
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
    return _cart.add(i, quantity: _quantity, note: _note.trim());
  }

  @override
  void dispose() {
    _cart.stop();
    add.dispose();
    super.dispose();
  }
}
