import 'package:breakbite/domain/models/cart_item.dart';
import 'package:breakbite/domain/models/order.dart';
import 'package:breakbite/utils/paged.dart';
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

  /// Live view of the newest orders of [uid] (S07, S02 reorder card).
  Stream<List<Order>> watchMyOrders(String uid);

  /// Orders of [uid], newest first, one page at a time (S08, S11, S14). Pass the previous page's
  /// `next` as [after] to load older orders. Fails with `ValidationException` for a bad [limit] or cursor.
  Future<Result<Paged<Order>>> fetchMyOrders(String uid, {int limit = Paged.defaultLimit, PageCursor? after});

  Future<Result<void>> cancelOrder(String id);

  /// Seller only.
  Stream<List<Order>> watchAllOrders();

  /// Seller only.
  Future<Result<void>> updateStatus(String id, OrderStatus status);
}
