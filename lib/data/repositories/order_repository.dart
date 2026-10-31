import 'package:breakbite/domain/models/cart_item.dart';
import 'package:breakbite/domain/models/order.dart';
import 'package:breakbite/utils/result.dart';

abstract interface class OrderRepository {
  /// Returns the new order id.
  Future<Result<String>> createOrder({
    required String uid,
    required List<CartItem> items,
    required int totalVnd,
    required PaymentMethod method,
    required String kioskId,
  });

  Stream<Order?> watchOrder(String id);

  Stream<List<Order>> watchMyOrders(String uid);

  Future<Result<void>> cancelOrder(String id);

  /// Seller only.
  Stream<List<Order>> watchAllOrders();

  /// Seller only.
  Future<Result<void>> updateStatus(String id, OrderStatus status);
}
