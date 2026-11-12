import 'package:breakbite_core/domain/models/cart_item.dart';
import 'package:breakbite_core/domain/models/kiosk_stats.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/domain/models/order_draft.dart';
import 'package:breakbite_core/utils/paged.dart';
import 'package:breakbite_core/utils/result.dart';

abstract interface class OrderRepository {
  static const minReadyIn = Duration(minutes: 1);

  Future<Result<String>> placeOrder(OrderDraft draft);

  Stream<Order?> watchOrder(String id);

  Stream<List<Order>> watchMyOrders(String uid, {int limit = Paged.defaultLimit});

  Stream<List<Order>> watchMyActiveOrders(String uid);

  Future<Result<Paged<Order>>> fetchMyOrders(String uid, {int limit = Paged.defaultLimit, PageCursor? after});

  Future<Result<int>> countMyOrders(String uid);

  Future<Result<void>> editPendingOrder(
    Order order, {
    required List<CartItem> items,
    String? voucherCode,
    String? pickupSlotId,
    String note = '',
  });

  Future<Result<void>> cancelMyOrder(Order order, {String? reason});

  Stream<List<Order>> watchKioskQueue(String kioskId);

  Future<Result<List<Order>>> findReadyByPickupCode(String kioskId, String pickupCode);

  Future<Result<void>> accept(Order order, {required Duration readyIn});

  Future<Result<void>> markReady(Order order);

  Future<Result<void>> deliver(Order order);

  Future<Result<void>> reject(Order order, {required String reason});

  /// The figures of K11 for orders a kiosk received at or after [since] (staff of that kiosk only).
  Future<Result<KioskStats>> kioskStats(String kioskId, {required DateTime since});
}
