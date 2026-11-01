import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/domain/order_pricing.dart';
import 'package:breakbite/utils/paged.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';
import 'paging.dart';

class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({this.vouchers = const {}});

  final Map<String, Voucher> vouchers;
  final _orders = LiveValue<List<Order>>(const []);
  var _seq = 203;
  var _clock = DateTime(2026, 11, 2, 9);

  static const _active = [OrderStatus.pending, OrderStatus.preparing, OrderStatus.ready];

  List<Order> get all => _orders.value;

  @override
  Future<Result<String>> placeOrder(OrderDraft draft) async {
    if (draft.items.isEmpty) return const Result.error(ValidationException('Giỏ hàng đang trống.'));
    final voucher = draft.voucherCode == null ? null : vouchers[draft.voucherCode];
    if (draft.voucherCode != null && voucher == null) {
      return const Result.error(NotFoundException(message: 'Mã giảm giá không tồn tại.'));
    }
    _clock = _clock.add(const Duration(minutes: 1));
    final pricing = priceOrder(draft.items, voucher: voucher, now: _clock);
    final id = 'A-${++_seq}';
    _orders.set([
      ..._orders.value,
      Order(
        id: id,
        uid: draft.uid,
        items: draft.items,
        subtotalVnd: pricing.subtotalVnd,
        discountVnd: pricing.discountVnd,
        totalVnd: pricing.totalVnd,
        voucherCode: voucher?.code,
        paymentMethod: draft.paymentMethod,
        paymentStatus: draft.paymentMethod == PaymentMethod.cash ? PaymentStatus.unpaid : PaymentStatus.paid,
        status: OrderStatus.pending,
        kioskId: draft.kioskId,
        kioskName: draft.kioskName,
        customerName: draft.customerName,
        pickupSlotId: draft.pickupSlotId,
        pickupCode: '${100000 + _seq}',
        note: draft.note,
        orderCode: id,
        createdAt: _clock,
      ),
    ]);
    return Result.ok(id);
  }

  @override
  Stream<Order?> watchOrder(String id) => _orders.stream.map((l) => l.where((o) => o.id == id).firstOrNull);

  @override
  Stream<List<Order>> watchMyOrders(String uid, {int limit = Paged.defaultLimit}) =>
      _orders.stream.map((l) => _newestFirst(l.where((o) => o.uid == uid)).take(limit).toList());

  @override
  Stream<List<Order>> watchMyActiveOrders(String uid) =>
      _orders.stream.map((l) => _newestFirst(l.where((o) => o.uid == uid && _active.contains(o.status))));

  @override
  Future<Result<Paged<Order>>> fetchMyOrders(String uid, {int limit = Paged.defaultLimit, PageCursor? after}) async =>
      pageOf(_newestFirst(_orders.value.where((o) => o.uid == uid)), limit: limit, after: after);

  @override
  Future<Result<int>> countMyOrders(String uid) async => Result.ok(_orders.value.where((o) => o.uid == uid).length);

  @override
  Future<Result<void>> editPendingOrder(
    Order order, {
    required List<CartItem> items,
    String? voucherCode,
    String? pickupSlotId,
    String note = '',
  }) async {
    final current = _find(order.id);
    if (current == null) return const Result.error(NotFoundException());
    if (current.status != OrderStatus.pending) {
      return const Result.error(ValidationException('Kiosk đã nhận đơn nên không sửa được nữa.'));
    }
    final voucher = voucherCode == null ? null : vouchers[voucherCode];
    final pricing = priceOrder(items, voucher: voucher, now: _clock);
    _replace(
      _copy(
        current,
        items: items,
        subtotalVnd: pricing.subtotalVnd,
        discountVnd: pricing.discountVnd,
        totalVnd: pricing.totalVnd,
        voucherCode: voucher?.code,
        pickupSlotId: pickupSlotId,
        note: note,
      ),
    );
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> cancelMyOrder(Order order, {String? reason}) => _move(
    order,
    from: const [OrderStatus.pending],
    to: OrderStatus.cancelled,
    cancelledBy: CancelledBy.customer,
    cancelReason: reason,
  );

  @override
  Stream<List<Order>> watchKioskQueue(String kioskId) =>
      _orders.stream.map((l) => _newestFirst(l.where((o) => o.kioskId == kioskId && _active.contains(o.status))));

  @override
  Future<Result<List<Order>>> findReadyByPickupCode(String kioskId, String pickupCode) async => Result.ok(
    _orders.value
        .where((o) => o.kioskId == kioskId && o.pickupCode == pickupCode && o.status == OrderStatus.ready)
        .toList(),
  );

  @override
  Future<Result<void>> accept(Order order, {required Duration readyIn}) =>
      _move(order, from: const [OrderStatus.pending], to: OrderStatus.preparing);

  @override
  Future<Result<void>> markReady(Order order) =>
      _move(order, from: const [OrderStatus.preparing], to: OrderStatus.ready);

  @override
  Future<Result<void>> deliver(Order order) => _move(order, from: const [OrderStatus.ready], to: OrderStatus.delivered);

  @override
  Future<Result<void>> reject(Order order, {required String reason}) {
    if (reason.trim().isEmpty) {
      return Future.value(const Result.error(ValidationException('Chọn hoặc nhập lý do từ chối đơn.')));
    }
    return _move(order, from: _active, to: OrderStatus.cancelled, cancelledBy: CancelledBy.staff, cancelReason: reason);
  }

  Future<Result<void>> _move(
    Order order, {
    required List<OrderStatus> from,
    required OrderStatus to,
    CancelledBy? cancelledBy,
    String? cancelReason,
  }) async {
    final current = _find(order.id);
    if (current == null) return const Result.error(NotFoundException(message: 'Không tìm thấy đơn hàng.'));
    if (!from.contains(current.status)) {
      return const Result.error(ValidationException('Đơn này vừa được xử lý ở nơi khác.'));
    }
    _replace(
      _copy(
        current,
        status: to,
        cancelledBy: cancelledBy,
        cancelReason: cancelReason,
        paymentStatus: to == OrderStatus.delivered ? PaymentStatus.paid : null,
      ),
    );
    return const Result.ok(null);
  }

  Order? _find(String id) => _orders.value.where((o) => o.id == id).firstOrNull;

  void _replace(Order next) => _orders.set([for (final o in _orders.value) o.id == next.id ? next : o]);

  List<Order> _newestFirst(Iterable<Order> orders) =>
      orders.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Order _copy(
    Order o, {
    OrderStatus? status,
    List<CartItem>? items,
    int? subtotalVnd,
    int? discountVnd,
    int? totalVnd,
    String? voucherCode,
    String? pickupSlotId,
    String? note,
    CancelledBy? cancelledBy,
    String? cancelReason,
    PaymentStatus? paymentStatus,
  }) => Order(
    id: o.id,
    uid: o.uid,
    items: items ?? o.items,
    totalVnd: totalVnd ?? o.totalVnd,
    paymentMethod: o.paymentMethod,
    status: status ?? o.status,
    kioskId: o.kioskId,
    createdAt: o.createdAt,
    orderCode: o.orderCode,
    customerName: o.customerName,
    kioskName: o.kioskName,
    subtotalVnd: subtotalVnd ?? o.subtotalVnd,
    discountVnd: discountVnd ?? o.discountVnd,
    voucherCode: items == null ? o.voucherCode : voucherCode,
    paymentStatus: paymentStatus ?? o.paymentStatus,
    pickupSlotId: items == null ? o.pickupSlotId : pickupSlotId,
    pickupAt: o.pickupAt,
    pickupCode: o.pickupCode,
    note: note ?? o.note,
    cancelReason: cancelReason ?? o.cancelReason,
    cancelledBy: cancelledBy ?? o.cancelledBy,
  );
}
