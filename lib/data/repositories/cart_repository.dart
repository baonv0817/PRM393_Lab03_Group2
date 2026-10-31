import 'package:breakbite/domain/models/cart_item.dart';
import 'package:breakbite/utils/result.dart';

abstract interface class CartRepository {
  Stream<List<CartItem>> watchCart(String uid);

  Future<Result<void>> addItem(String uid, CartItem item);

  Future<Result<void>> setQuantity(String uid, String itemId, int quantity);

  Future<Result<void>> clear(String uid);
}
