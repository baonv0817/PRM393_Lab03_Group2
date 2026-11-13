import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/cart_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCartRepository implements CartRepository {
  FirestoreCartRepository(this._db);

  static const otherKioskMessage = 'Giỏ hàng đang có món của kiosk khác. Xoá giỏ trước khi đặt ở kiosk này.';

  final FirebaseFirestore _db;

  DocumentReference<Json> _cart(String uid) => _db.collection('carts').doc(uid);

  @override
  Stream<Cart> watchCart(String uid) =>
      guardStream(_cart(uid).snapshots().map((snapshot) => cartFromData(snapshot.data())));

  @override
  Future<Result<void>> addItem(String uid, {required String kioskId, required CartItem item}) {
    if (item.quantity < 1 || item.quantity > Cart.maxQuantity || item.priceVnd <= 0 || item.itemId.isEmpty) {
      return Future.value(const Result.error(ValidationException('Món hoặc số lượng không hợp lệ.')));
    }
    return _edit(uid, (cart) {
      if (!cart.isEmpty && cart.kioskId != kioskId) throw const ValidationException(otherKioskMessage);
      final base = cart.isEmpty && cart.kioskId != kioskId ? Cart(kioskId: kioskId) : cart;
      final lines = [...base.items];
      final index = lines.indexWhere((line) => line.lineKey == item.lineKey);
      if (index == -1) {
        lines.add(item);
      } else {
        lines[index] = lines[index].copyWith(quantity: lines[index].quantity + item.quantity);
      }
      return _with(base, items: lines, kioskId: kioskId);
    });
  }

  @override
  Future<Result<void>> setQuantity(String uid, String lineKey, int quantity) => _edit(uid, (cart) {
    if (!cart.items.any((line) => line.lineKey == lineKey)) return null;
    return _with(
      cart,
      items: [
        for (final line in cart.items)
          if (line.lineKey != lineKey) line else if (quantity > 0) line.copyWith(quantity: quantity),
      ],
    );
  });

  @override
  Future<Result<void>> setNote(String uid, String lineKey, String note) => _edit(uid, (cart) {
    if (!cart.items.any((line) => line.lineKey == lineKey)) return null;
    return _with(
      cart,
      items: [for (final line in cart.items) line.lineKey == lineKey ? line.copyWith(note: note.trim()) : line],
    );
  });

  @override
  Future<Result<void>> replaceItems(String uid, List<CartItem> items) =>
      _edit(uid, (cart) => _with(cart, items: items));

  @override
  Future<Result<void>> setVoucher(String uid, String? code) => _edit(uid, (cart) {
    if (cart.isEmpty) throw const ValidationException('Giỏ hàng đang trống.');
    final normalized = code?.trim().toUpperCase();
    return _with(cart, voucherCode: normalized == null || normalized.isEmpty ? null : normalized, keepVoucher: false);
  });

  @override
  Future<Result<void>> setPickup(String uid, PickupSlot? slot) => _edit(uid, (cart) {
    if (cart.isEmpty) throw const ValidationException('Giỏ hàng đang trống.');
    return _with(cart, pickupSlotId: slot?.id, pickupAt: slot?.startAt, keepPickup: false);
  });

  @override
  Future<Result<void>> clear(String uid) => guard(() => _cart(uid).delete());

  Cart _with(
    Cart cart, {
    List<CartItem>? items,
    String? kioskId,
    String? voucherCode,
    bool keepVoucher = true,
    String? pickupSlotId,
    DateTime? pickupAt,
    bool keepPickup = true,
  }) => Cart(
    kioskId: kioskId ?? cart.kioskId,
    items: items ?? cart.items,
    voucherCode: keepVoucher ? cart.voucherCode : voucherCode,
    pickupSlotId: keepPickup ? cart.pickupSlotId : pickupSlotId,
    pickupAt: keepPickup ? cart.pickupAt : pickupAt,
  );

  Future<Result<void>> _edit(String uid, Cart? Function(Cart current) change) {
    final ref = _cart(uid);
    return runGuardedTransaction<void>(_db, (tx) async {
      final snapshot = await tx.get(ref);
      final next = change(cartFromData(snapshot.data()));
      if (next == null) return;
      _check(next);
      if (next.isEmpty) {
        if (snapshot.exists) tx.delete(ref);
        return;
      }
      final data = cartToData(next);
      if (snapshot.exists) {
        tx.update(ref, {for (final e in data.entries) e.key: e.value ?? FieldValue.delete(), ...Stamp.updated()});
      } else {
        tx.set(ref, {
          for (final e in data.entries)
            if (e.value != null) e.key: e.value!,
          ...Stamp.created(),
        });
      }
    });
  }

  void _check(Cart cart) {
    if (cart.items.length > Cart.maxLines) {
      throw const ValidationException('Giỏ hàng tối đa ${Cart.maxLines} món khác nhau.');
    }
    if (cart.items.any((line) => line.quantity > Cart.maxQuantity)) {
      throw const ValidationException('Mỗi món tối đa ${Cart.maxQuantity} phần.');
    }
    if (!cart.isEmpty && (cart.kioskId == null || cart.kioskId!.isEmpty)) {
      throw const ValidationException('Giỏ hàng chưa chọn kiosk.');
    }
  }
}
