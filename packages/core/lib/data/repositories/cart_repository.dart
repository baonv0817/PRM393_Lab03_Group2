import 'package:breakbite_core/domain/models/cart.dart';
import 'package:breakbite_core/domain/models/cart_item.dart';
import 'package:breakbite_core/domain/models/pickup_slot.dart';
import 'package:breakbite_core/utils/result.dart';

abstract interface class CartRepository {
  Stream<Cart> watchCart(String uid);

  Future<Result<void>> addItem(String uid, {required String kioskId, required CartItem item});

  /// [lineKey] is `CartItem.lineKey`: the dish id for a dish without options.
  Future<Result<void>> setQuantity(String uid, String lineKey, int quantity);

  Future<Result<void>> setNote(String uid, String lineKey, String note);

  Future<Result<void>> replaceItems(String uid, List<CartItem> items);

  Future<Result<void>> setVoucher(String uid, String? code);

  Future<Result<void>> setPickup(String uid, PickupSlot? slot);

  Future<Result<void>> clear(String uid);
}
