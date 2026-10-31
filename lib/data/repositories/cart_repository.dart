import '../../domain/models/cart_item.dart';

abstract interface class CartRepository {
  Stream<List<CartItem>> watchCart(String uid);
  Future<void> addItem(String uid, CartItem item);
  Future<void> setQuantity(String uid, String itemId, int quantity);
  Future<void> clear(String uid);
}
