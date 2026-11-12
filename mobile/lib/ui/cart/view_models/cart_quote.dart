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
  }

  void _onCart(Cart value) {
    _cart = value;
    _onChanged();
    if (value.voucherCode != _voucherCode) unawaited(_loadVoucher(value.voucherCode));
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
    if (!k.acceptsOrders(now)) return '${k.name} đang tạm ngưng nhận đơn. ${kioskStatusLabel(k, now: now)}.';
    return null;
  }

  DateTime get readyAt => value.pickupAt ?? now.add(Duration(minutes: kiosk?.waitMinutes ?? 0));
}
