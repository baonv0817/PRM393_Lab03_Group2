import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/paged.dart';
import 'package:breakbite_core/utils/result.dart';

import '../live_value.dart';

class _IndexCursor implements PageCursor {
  const _IndexCursor(this.next);

  final int next;
}

/// Orders of several kiosks held in memory. Filters and pages like the Firestore version: newest first, a cursor
/// that points after the last order of a page.
class FakeAdminOrderRepository implements AdminOrderRepository {
  FakeAdminOrderRepository({List<Order>? orders, DateTime? now}) : _orders = orders ?? _seed(now ?? DateTime.now());

  /// A few orders over the last days, in two kiosks, in every state. The newest are first.
  static List<Order> _seed(DateTime now) {
    Order order(
      String id,
      Duration age, {
      String kiosk = 'q9-t2',
      OrderStatus status = OrderStatus.delivered,
      int total = 40000,
      List<CartItem>? items,
      int? prep,
      PaymentMethod method = PaymentMethod.momo,
    }) => Order(
      id: id,
      uid: 'user-1',
      orderCode: id.toUpperCase(),
      customerName: 'Nguyễn Minh Quân',
      kioskId: kiosk,
      kioskName: kiosk == 'q9-t2' ? 'Kiosk Q9 · Tầng 2' : 'Kiosk Q9 · Tầng 4',
      items: items ?? const [CartItem(itemId: 'q9-t2-tacos-bo', name: 'Combo Tacos Bò Phô Mai', priceVnd: 40000)],
      subtotalVnd: total,
      totalVnd: total,
      paymentMethod: method,
      paymentStatus: status == OrderStatus.delivered ? PaymentStatus.paid : PaymentStatus.unpaid,
      status: status,
      createdAt: now.subtract(age),
      prepSeconds: prep,
    );
    return [
      order('o1', const Duration(minutes: 40), status: OrderStatus.pending, method: PaymentMethod.cash),
      order('o2', const Duration(minutes: 5), status: OrderStatus.preparing, kiosk: 'q9-t4'),
      order('o3', const Duration(hours: 3), prep: 240),
      order(
        'o4',
        const Duration(hours: 5),
        kiosk: 'q9-t4',
        total: 60000,
        prep: 300,
        items: const [CartItem(itemId: 'q9-t4-tra-dao', name: 'Trà Đào Chanh Sả', priceVnd: 30000, quantity: 2)],
      ),
      order('o5', const Duration(days: 1), status: OrderStatus.cancelled),
      order('o6', const Duration(days: 2), prep: 180),
      order('o7', const Duration(days: 3), kiosk: 'q9-t4', prep: 360, total: 20000),
    ];
  }

  final List<Order> _orders;
  AppException? failNext;

  List<Order> get orders => _orders;

  Result<T>? _failure<T>() {
    final error = failNext;
    failNext = null;
    return error == null ? null : Result.error(error);
  }

  List<Order> _matching(OrderQuery q) => [
    for (final o in _orders)
      if ((q.kioskId == null || o.kioskId == q.kioskId) &&
          (q.status == null || o.status == q.status) &&
          (q.from == null || !o.createdAt.isBefore(q.from!)) &&
          (q.to == null || o.createdAt.isBefore(q.to!)))
        o,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Result<Paged<Order>>> fetchOrders(OrderQuery query, {int limit = 25, PageCursor? after}) async {
    if (_failure<Paged<Order>>() case final failed?) return failed;
    if (Paged.checkLimit(limit) case final error?) return Result.error(error);
    final start = after is _IndexCursor ? after.next : 0;
    final all = _matching(query);
    final slice = all.skip(start).take(limit + 1).toList();
    return Result.ok(
      pageFromOverfetch(
        slice,
        limit: limit,
        map: (o) => o,
        cursorOf: (o) => _IndexCursor(start + slice.indexOf(o) + 1),
      ),
    );
  }

  @override
  Future<Result<List<Order>>> fetchRange({required DateTime from, required DateTime to, String? kioskId}) async {
    if (_failure<List<Order>>() case final failed?) return failed;
    return Result.ok(
      _matching(OrderQuery(kioskId: kioskId, from: from, to: to)).take(AdminOrderRepository.maxRange).toList(),
    );
  }
}

/// The reports of customers held in memory, with a way to add one.
class FakeAdminIncidentRepository implements AdminIncidentRepository {
  FakeAdminIncidentRepository({List<Incident>? incidents, DateTime? now})
    : _incidents = LiveValue(incidents ?? _seed(now ?? DateTime.now()));

  static List<Incident> _seed(DateTime now) => [
    Incident(
      orderId: 'o3',
      kioskId: 'q9-t2',
      uid: 'user-1',
      customerName: 'Nguyễn Minh Quân',
      type: IncidentType.missingItem,
      description: 'Thiếu nước ngọt',
      status: IncidentStatus.open,
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    Incident(
      orderId: 'o4',
      kioskId: 'q9-t4',
      uid: 'user-2',
      customerName: 'Trần Bảo An',
      type: IncidentType.quality,
      description: 'Trà bị nhạt',
      status: IncidentStatus.resolved,
      resolution: IncidentResolution.refunded,
      refundVnd: 30000,
      handledBy: 'staff-2',
      createdAt: now.subtract(const Duration(days: 1)),
      resolvedAt: now.subtract(const Duration(hours: 20)),
    ),
  ];

  final LiveValue<List<Incident>> _incidents;

  void add(Incident incident) => _incidents.set([incident, ..._incidents.value]);

  @override
  Stream<List<Incident>> watchAll() => _incidents.stream;
}
