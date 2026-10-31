import '../../domain/models/cart_item.dart';
import '../../domain/models/order.dart';

abstract interface class OrderRepository {
  Future<String> createOrder({
    required String uid,
    required List<CartItem> items,
    required int totalVnd,
    required PaymentMethod method,
    required String kioskId,
  });
  Stream<Order?> watchOrder(String id);
  Stream<List<Order>> watchMyOrders(String uid);
  Future<void> cancelOrder(String id);

  /// Người bán.
  Stream<List<Order>> watchAllOrders();
  Future<void> updateStatus(String id, OrderStatus status);
}
