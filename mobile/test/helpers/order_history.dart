import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/paged.dart';
import 'package:breakbite_core/utils/result.dart';

import '../../dev/fakes/fakes.dart';

/// Serves a fixed list (newest first) a page at a time, and can fail the next call.
class PagedOrders extends FakeOrderRepository {
  PagedOrders(this.data);

  final List<Order> data;
  AppException? failNext;
  int calls = 0;

  @override
  Future<Result<Paged<Order>>> fetchMyOrders(String uid, {int limit = Paged.defaultLimit, PageCursor? after}) async {
    calls++;
    if (failNext case final error?) {
      failNext = null;
      return Result.error(error);
    }
    return pageOf(data, limit: limit, after: after);
  }
}

/// An order of 'u1' placed at [createdAt]; by default delivered for 39.000đ.
Order historyOrder(
  String id,
  DateTime createdAt, {
  OrderStatus status = OrderStatus.delivered,
  int total = 39000,
  DateTime? deliveredAt,
}) => Order(
  id: id,
  uid: 'u1',
  orderCode: id.toUpperCase(),
  kioskId: 'q9-t2',
  kioskName: 'Kiosk',
  items: [CartItem(itemId: 'm1', name: 'Combo', priceVnd: total)],
  totalVnd: total,
  paymentMethod: PaymentMethod.momo,
  status: status,
  createdAt: createdAt,
  deliveredAt: deliveredAt,
);
