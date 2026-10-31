import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';

class FakeOrderRepository implements OrderRepository {
  final _orders = LiveValue<List<Order>>(const []);
  var _seq = 203;

  @override
  Future<Result<String>> createOrder({
    required String uid,
    required List<CartItem> items,
    required int totalVnd,
    required PaymentMethod method,
    required String kioskId,
  }) async {
    final id = 'A-${++_seq}';
    _orders.set([
      ..._orders.value,
      Order(
        id: id,
        uid: uid,
        items: items,
        totalVnd: totalVnd,
        paymentMethod: method,
        status: OrderStatus.pending,
        kioskId: kioskId,
        createdAt: DateTime.now(),
      ),
    ]);
    return Result.ok(id);
  }

  @override
  Stream<Order?> watchOrder(String id) => _orders.stream.map((l) => l.where((o) => o.id == id).firstOrNull);

  @override
  Stream<List<Order>> watchMyOrders(String uid) => _orders.stream.map((l) => l.where((o) => o.uid == uid).toList());

  @override
  Future<Result<void>> cancelOrder(String id) => updateStatus(id, OrderStatus.cancelled);

  @override
  Stream<List<Order>> watchAllOrders() => _orders.stream;

  @override
  Future<Result<void>> updateStatus(String id, OrderStatus status) async {
    _orders.set([
      for (final o in _orders.value)
        o.id == id
            ? Order(
                id: o.id,
                uid: o.uid,
                items: o.items,
                totalVnd: o.totalVnd,
                paymentMethod: o.paymentMethod,
                status: status,
                kioskId: o.kioskId,
                createdAt: o.createdAt,
              )
            : o,
    ]);
    return const Result.ok(null);
  }
}
