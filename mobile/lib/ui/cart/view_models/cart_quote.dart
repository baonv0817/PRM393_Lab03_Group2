import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/domain/order_pricing.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';

class CartQuote {
  CartQuote({
    required this.cart,
    required this.menu,
    required this.crash,
    required this.uid,
    required this._onChanged,
    required this._clock,
    required this._reason,
  });

  final CartRepository cart;
  final MenuRepository menu;
  final CrashService crash;
  final String uid;
  final void Function() _onChanged;
  final DateTime Function() _clock;
  final String _reason;

  StreamSubscription<Cart>? _cartSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  StreamSubscription<List<MenuItem>>? _menuSub;
  String? _menuKioskId;
  Map<String, String?> _images = const {};
  Cart? _cart;
  List<Kiosk>? _kiosks;
  String? _loadError;
  String? _voucherCode;
  Voucher? _voucher;
  String? _voucherMissing;

  bool get loaded => _cart != null && _kiosks != null;
  String? get loadError => _loadError;
  Cart get value => _cart ?? Cart.empty;
  Voucher? get voucher => _voucher;
  DateTime get now => _clock();

  /// The photo of a cart line, from the kiosk's menu (D42); null until the menu arrives or when the item has none.
  String? imageOf(String itemId) => _images[itemId];

  Kiosk? get kiosk {
    final id = value.kioskId;
    return id == null ? null : _kiosks?.where((k) => k.id == id).firstOrNull;
  }

  void start() {
    stop();
    _loadError = null;
    _cart = null;
    _kiosks = null;
    _onChanged();
    _cartSub = cart.watchCart(uid).listen(_onCart, onError: _onError);
    _kioskSub = menu.watchKiosks().listen((kiosks) {
      _kiosks = kiosks;
      _onChanged();
    }, onError: _onError);
  }

  void stop() {
    unawaited(_cartSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_menuSub?.cancel());
    _menuSub = null;
    _menuKioskId = null;
  }

  void _onCart(Cart value) {
    _cart = value;
    _watchMenu(value.kioskId);
    _onChanged();
    if (value.voucherCode != _voucherCode) unawaited(_loadVoucher(value.voucherCode));
  }

  /// Follows the menu of the cart's kiosk for the photos only: a failure leaves the dish icon and is not an error of
  /// the cart.
  void _watchMenu(String? kioskId) {
    if (kioskId == _menuKioskId) return;
    unawaited(_menuSub?.cancel());
    _menuKioskId = kioskId;
    _images = const {};
    if (kioskId == null) return;
    _menuSub = menu.watchMenu(kioskId, includeArchived: true).listen((items) {
      _images = {for (final i in items) i.id: i.imageUrl};
      _onChanged();
    }, onError: (Object error, StackTrace stack) => crash.recordNonFatal(error, stack, '$_reason.menuImages'));
  }

  void _onError(Object error, StackTrace stack) {
    crash.recordNonFatal(error, stack, '$_reason.load');
    _loadError = error is AppException ? error.message : 'Không tải được giỏ hàng.';
    _onChanged();
  }

  Future<void> _loadVoucher(String? code) async {
    _voucherCode = code;
    _voucher = null;
    _voucherMissing = null;
    if (code == null) {
      _onChanged();
      return;
    }
    final result = await menu.getVoucher(code);
    if (code != _voucherCode) return;
    switch (result) {
      case Ok(:final value):
        _voucher = value;
      case Err(error: NotFoundException()):
        _voucherMissing = 'Mã $code không tồn tại hoặc đã bị gỡ.';
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, '$_reason.voucher');
        _voucherMissing = error.message;
    }
    _onChanged();
  }

  OrderPricing price(List<CartItem> items) => priceOrder(items, voucher: _voucher, now: now);

  String? voucherProblem(int subtotalVnd) {
    if (_voucherMissing case final message?) return message;
    final voucher = _voucher;
    if (voucher == null) return null;
    final problem = voucher.problemFor(subtotalVnd, now);
    return problem == null ? null : voucherProblemMessage(voucher, problem);
  }

  String? get kioskProblem {
    final k = kiosk;
    if (value.isEmpty) return null;
    if (k == null) return 'Không tìm thấy kiosk của giỏ hàng.';
    if (!k.acceptsOrders(now)) {
      final why = k.open && !k.isWithinHours(now) ? 'đang ngoài giờ mở cửa' : 'đang tạm ngưng nhận đơn';
      return '${k.name} $why. ${kioskStatusLabel(k, now: now)}.';
    }
    return null;
  }

  DateTime get readyAt => value.pickupAt ?? now.add(Duration(minutes: kiosk?.waitMinutes ?? 0));
}
