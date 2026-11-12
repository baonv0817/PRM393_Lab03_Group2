import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/paged.dart';
import 'package:breakbite_core/utils/result.dart';

/// What the admin's order list is filtered by; every part is optional.
class OrderQuery {
  const OrderQuery({this.kioskId, this.status, this.from, this.to});

  final String? kioskId;
  final OrderStatus? status;

  /// Orders placed at or after this moment.
  final DateTime? from;

  /// Orders placed before this moment.
  final DateTime? to;

  OrderQuery copyWith({Object? kioskId = _keep, Object? status = _keep, Object? from = _keep, Object? to = _keep}) =>
      OrderQuery(
        kioskId: identical(kioskId, _keep) ? this.kioskId : kioskId as String?,
        status: identical(status, _keep) ? this.status : status as OrderStatus?,
        from: identical(from, _keep) ? this.from : from as DateTime?,
        to: identical(to, _keep) ? this.to : to as DateTime?,
      );

  static const _keep = Object();
}

/// The orders of every kiosk, read-only, for the admin website (A06 orders, A08 statistics).
abstract interface class AdminOrderRepository {
  /// Most orders one statistics period reads; the report says when there were more.
  static const maxRange = 2000;

  /// A page of the orders that match [query], newest first, read with a cursor.
  Future<Result<Paged<Order>>> fetchOrders(OrderQuery query, {int limit = 25, PageCursor? after});

  /// The orders placed from [from] up to (not including) [to], newest first, at most [maxRange] of them, for
  /// [kioskId] or for every kiosk. `Ok` with exactly [maxRange] orders means there may be more.
  Future<Result<List<Order>>> fetchRange({required DateTime from, required DateTime to, String? kioskId});
}
