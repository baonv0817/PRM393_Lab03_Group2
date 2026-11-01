import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';

class FakeCartRepository implements CartRepository {
  final _carts = <String, LiveValue<Cart>>{};

  LiveValue<Cart> _of(String uid) => _carts.putIfAbsent(uid, () => LiveValue(Cart.empty));

  Cart current(String uid) => _of(uid).value;

  @override
  Stream<Cart> watchCart(String uid) => _of(uid).stream;

  @override
  Future<Result<void>> addItem(String uid, {required String kioskId, required CartItem item}) async {
    final cart = _of(uid);
    if (!cart.value.isEmpty && cart.value.kioskId != kioskId) {
      return const Result.error(ValidationException('Giỏ hàng đang có món của kiosk khác.'));
    }
    final list = [...cart.value.items];
    final i = list.indexWhere((e) => e.itemId == item.itemId);
    i == -1 ? list.add(item) : list[i] = list[i].copyWith(quantity: list[i].quantity + item.quantity);
    cart.set(_copy(cart.value, kioskId: kioskId, items: list));
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setQuantity(String uid, String itemId, int quantity) async {
    final cart = _of(uid);
    _put(uid, [
      for (final e in cart.value.items)
        if (e.itemId != itemId) e else if (quantity > 0) e.copyWith(quantity: quantity),
    ]);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setNote(String uid, String itemId, String note) async {
    _put(uid, [for (final e in _of(uid).value.items) e.itemId == itemId ? e.copyWith(note: note) : e]);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> replaceItems(String uid, List<CartItem> items) async {
    _put(uid, items);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setVoucher(String uid, String? code) async {
    final cart = _of(uid);
    if (cart.value.isEmpty) return const Result.error(ValidationException('Giỏ hàng đang trống.'));
    cart.set(_copy(cart.value, voucherCode: code?.toUpperCase(), replaceVoucher: true));
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setPickup(String uid, PickupSlot? slot) async {
    final cart = _of(uid);
    if (cart.value.isEmpty) return const Result.error(ValidationException('Giỏ hàng đang trống.'));
    cart.set(_copy(cart.value, pickupSlotId: slot?.id, pickupAt: slot?.startAt, replacePickup: true));
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> clear(String uid) async {
    _of(uid).set(Cart.empty);
    return const Result.ok(null);
  }

  void _put(String uid, List<CartItem> items) {
    final cart = _of(uid);
    cart.set(items.isEmpty ? Cart.empty : _copy(cart.value, items: items));
  }

  Cart _copy(
    Cart cart, {
    String? kioskId,
    List<CartItem>? items,
    String? voucherCode,
    bool replaceVoucher = false,
    String? pickupSlotId,
    DateTime? pickupAt,
    bool replacePickup = false,
  }) => Cart(
    kioskId: kioskId ?? cart.kioskId,
    items: items ?? cart.items,
    voucherCode: replaceVoucher ? voucherCode : cart.voucherCode,
    pickupSlotId: replacePickup ? pickupSlotId : cart.pickupSlotId,
    pickupAt: replacePickup ? pickupAt : cart.pickupAt,
  );
}
