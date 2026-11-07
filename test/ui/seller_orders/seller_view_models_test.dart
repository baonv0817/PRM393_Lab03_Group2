import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_incidents_view_model.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_order_actions.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_order_view_model.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_orders_view_model.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_scan_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

final _now = DateTime(2026, 11, 2, 10);

Order _order({DateTime? pickupAt, int status = 0}) => Order(
  id: 'A-1',
  uid: 'u',
  items: const [CartItem(itemId: 'm1', name: 'Combo', priceVnd: 39000)],
  totalVnd: 39000,
  paymentMethod: PaymentMethod.momo,
  status: OrderStatus.values[status],
  kioskId: 'q9-t2',
  createdAt: _now,
  pickupAt: pickupAt,
);

SellerOrdersViewModel _orders(
  FakeOrderRepository orders, {
  String? kioskId = 'q9-t2',
  FakeIncidentRepository? incidents,
}) => SellerOrdersViewModel(
  orders: orders,
  menu: FakeMenuRepository(),
  incidents: incidents ?? FakeIncidentRepository(),
  crash: FakeCrashService(),
  kioskId: kioskId,
  clock: () => _now,
);

SellerOrderViewModel _one(FakeOrderRepository orders, String id, {String? kioskId = 'q9-t2'}) => SellerOrderViewModel(
  orders: orders,
  menu: FakeMenuRepository(),
  crash: FakeCrashService(),
  orderId: id,
  kioskId: kioskId,
  clock: () => _now,
);

void main() {
  group('readyInFor and the reject reasons', () {
    test('uses the pickup time when it is far enough, else the kiosk wait, never below 5 minutes', () {
      expect(
        readyInFor(_order(pickupAt: _now.add(const Duration(minutes: 12))), now: _now),
        const Duration(minutes: 12),
      );
      expect(
        readyInFor(_order(pickupAt: _now.add(const Duration(seconds: 20))), now: _now),
        const Duration(minutes: 5),
      );
      expect(readyInFor(_order(), now: _now, kioskWaitMinutes: 9), const Duration(minutes: 9));
      expect(readyInFor(_order(), now: _now, kioskWaitMinutes: 2), const Duration(minutes: 5));
    });

    test('"other" needs a typed reason; the others are saved with an optional note', () {
      expect(rejectReasonProblem(RejectReason.other, '  '), isNotNull);
      expect(rejectReasonProblem(RejectReason.soldOut, ''), isNull);
      expect(rejectReasonText(RejectReason.soldOut, ''), 'Hết món');
      expect(rejectReasonText(RejectReason.busy, 'đông quá'), 'Quá tải, không kịp giờ: đông quá');
      expect(rejectReasonText(RejectReason.other, ' hỏng bếp '), 'hỏng bếp');
    });
  });

  group('countdownLabel (K04)', () {
    test('counts down, then up when late, and says hours instead of a huge number of minutes', () {
      expect(countdownLabel(const Duration(minutes: 2, seconds: 35)), 'Còn 02:35');
      expect(countdownLabel(const Duration(seconds: -40)), 'Trễ 00:40');
      expect(countdownLabel(const Duration(minutes: -59, seconds: -59)), 'Trễ 59:59');
      expect(countdownLabel(const Duration(hours: -15, minutes: -8)), 'Trễ hơn 15 giờ');
      expect(countdownLabel(null), 'Đang làm');
    });
  });

  group('SellerOrdersViewModel (K02)', () {
    test('shows the orders of the kiosk in three tabs with counts, oldest first', () async {
      final repo = FakeOrderRepository();
      final a = await placeTestOrder(repo, uid: 'u1');
      await placeTestOrder(repo, uid: 'u2');
      await placeTestOrder(repo, uid: 'u3', kioskId: 'q9-t4');
      await repo.accept(repo.all.firstWhere((o) => o.id == a), readyIn: const Duration(minutes: 4));
      final vm = _orders(repo);
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<List<Order>>>());
      expect(SellerOrderTab.values.map(vm.countOf), [1, 1, 0]);
      expect(vm.visible.map((o) => o.id), ['A-205']);
      vm.select(SellerOrderTab.preparing);
      expect(vm.visible.map((o) => o.id), ['A-204']);
      expect(vm.acceptsOrders, isTrue);
      expect(vm.statusLine, startsWith('Mở'));
    });

    test('a kiosk-less account sees the explanation, not an empty list', () async {
      final vm = _orders(FakeOrderRepository(), kioskId: null);
      expect(vm.state, isA<ViewEmpty<List<Order>>>());
      expect((vm.state as ViewEmpty).message, SellerOrdersViewModel.noKioskMessage);
      expect(vm.hasKiosk, isFalse);
    });

    test('accepting moves the order to "Đang làm" and counts open incidents for the bell', () async {
      final repo = FakeOrderRepository();
      final id = await placeTestOrder(repo, uid: 'u1');
      final incidents = FakeIncidentRepository();
      final order = repo.all.single;
      await incidents.report(order: order, type: IncidentType.missingItem, description: 'Thiếu trà');
      final vm = _orders(repo, incidents: incidents);
      await pumpEventQueue();

      expect(vm.openIncidents, 1);
      expect(await vm.accept(vm.visible.single), isA<Ok<void>>());
      await pumpEventQueue();
      expect(repo.all.firstWhere((o) => o.id == id).status, OrderStatus.preparing);
      expect(vm.countOf(SellerOrderTab.pending), 0);
      expect(vm.countOf(SellerOrderTab.preparing), 1);
    });

    test('an order that was handled elsewhere gives an error message, not a crash', () async {
      final repo = FakeOrderRepository();
      await placeTestOrder(repo, uid: 'u1');
      final stale = repo.all.single;
      await repo.accept(stale, readyIn: const Duration(minutes: 3));
      final vm = _orders(repo);
      await pumpEventQueue();

      final result = await vm.accept(stale);
      expect(result, isA<Err<void>>());
      expect(vm.busyOrderId, isNull);
    });
  });

  group('SellerOrderViewModel (K03, K04, K06, K12)', () {
    test('walks an order from new to delivered, and ticks the check list', () async {
      final repo = FakeOrderRepository();
      final id = await placeTestOrder(
        repo,
        uid: 'u1',
        items: const [
          CartItem(itemId: 'a', name: 'A', priceVnd: 1000),
          CartItem(itemId: 'b', name: 'B', priceVnd: 2000),
        ],
      );
      final vm = _one(repo, id);
      await pumpEventQueue();

      expect(vm.order?.status, OrderStatus.pending);
      expect(await vm.accept(), isA<Ok<void>>());
      await pumpEventQueue();
      expect(vm.order?.status, OrderStatus.preparing);
      expect(vm.timeLeft, isNotNull);

      expect(vm.allChecked, isFalse);
      vm
        ..toggle(0)
        ..toggle(1);
      expect(vm.allChecked, isTrue);
      vm.toggle(1);
      expect(vm.isChecked(1), isFalse);

      expect(await vm.markReady(), isA<Ok<void>>());
      await pumpEventQueue();
      expect(await vm.deliver(), isA<Ok<void>>());
      await pumpEventQueue();
      expect(vm.order?.status, OrderStatus.delivered);
    });

    test('a cash order is collected at the handover (K06-CASH)', () async {
      final repo = FakeOrderRepository();
      final id = await placeTestOrder(repo, uid: 'u1', method: PaymentMethod.cash);
      final vm = _one(repo, id);
      await pumpEventQueue();
      expect(vm.isCashToCollect, isTrue);
      await vm.accept();
      await pumpEventQueue();
      await vm.markReady();
      await pumpEventQueue();
      await vm.deliver();
      await pumpEventQueue();
      expect(vm.isCashToCollect, isFalse);
    });

    test('rejecting needs a reason, cancels the order and records who did it', () async {
      final repo = FakeOrderRepository();
      final id = await placeTestOrder(repo, uid: 'u1');
      final vm = _one(repo, id);
      await pumpEventQueue();

      expect(await vm.reject('  '), isA<Err<void>>());
      expect(await vm.reject('Hết món'), isA<Ok<void>>());
      await pumpEventQueue();
      expect(vm.order?.status, OrderStatus.cancelled);
      expect((vm.order?.cancelledBy, vm.order?.cancelReason), (CancelledBy.staff, 'Hết món'));
    });

    test('an order of another kiosk or a missing one is not shown', () async {
      final repo = FakeOrderRepository();
      final id = await placeTestOrder(repo, uid: 'u1', kioskId: 'q9-t4');
      final mine = _one(repo, id, kioskId: 'q9-t4');
      final other = _one(repo, id);
      final missing = _one(repo, 'nope');
      await pumpEventQueue();

      expect(mine.state, isA<ViewData<Order>>());
      expect(other.state, isA<ViewEmpty<Order>>());
      expect((other.state as ViewEmpty).message, SellerOrderViewModel.notYoursMessage);
      expect((missing.state as ViewEmpty).message, SellerOrderViewModel.notFoundMessage);
      expect(await missing.accept(), isA<Err<void>>());
    });
  });

  group('SellerScanViewModel (K05)', () {
    Future<(FakeOrderRepository, SellerScanViewModel, Order)> ready() async {
      final repo = FakeOrderRepository();
      final id = await placeTestOrder(repo, uid: 'u1');
      final order = repo.all.firstWhere((o) => o.id == id);
      await repo.accept(order, readyIn: const Duration(minutes: 3));
      await repo.markReady(repo.all.firstWhere((o) => o.id == id));
      final vm = SellerScanViewModel(orders: repo, crash: FakeCrashService(), kioskId: 'q9-t2');
      return (repo, vm, repo.all.firstWhere((o) => o.id == id));
    }

    test('parses a QR payload, a pickup code with spaces and an order number', () {
      expect(SellerScanViewModel.parse('bb:A-204:100204').orderId, 'A-204');
      expect(SellerScanViewModel.parse('100 204').pickupCode, '100204');
      expect(SellerScanViewModel.parse('#a-204').orderNumber, 'A-204');
      final empty = SellerScanViewModel.parse('   ');
      expect((empty.orderId, empty.pickupCode, empty.orderNumber), (null, null, null));
    });

    test('finds a ready order by pickup code, by QR text and by number', () async {
      final (_, vm, order) = await ready();
      for (final input in [order.pickupCode, order.qrPayload, '#${order.orderCode}']) {
        final result = await vm.find(input);
        expect(result.valueOrNull?.id, order.id, reason: input);
      }
      expect(vm.error, isNull);
    });

    test('a wrong, spent or other-kiosk code gives the invalid message (K05-ERR) until the next edit', () async {
      final (repo, vm, order) = await ready();
      expect(await vm.find('#A-999'), isA<Err<Order>>());
      expect(vm.error, SellerScanViewModel.invalidMessage);
      vm.clearError();
      expect(vm.error, isNull);

      await repo.deliver(order);
      expect(await vm.find(order.pickupCode), isA<Err<Order>>());
      expect(vm.error, SellerScanViewModel.invalidMessage);

      final other = SellerScanViewModel(orders: repo, crash: FakeCrashService(), kioskId: 'q9-t4');
      expect(await other.find(order.pickupCode), isA<Err<Order>>());
    });

    test('an empty input and a kiosk-less account are refused', () async {
      final (repo, vm, _) = await ready();
      expect(await vm.find('  '), isA<Err<Order>>());
      expect(vm.error, SellerScanViewModel.emptyMessage);
      final none = SellerScanViewModel(orders: repo, crash: FakeCrashService(), kioskId: null);
      expect((await none.find('123456')).errorOrNull, isA<PermissionDeniedException>());
    });
  });

  group('SellerIncidentsViewModel (K13)', () {
    Future<(SellerIncidentsViewModel, FakeIncidentRepository, Order)> setUp() async {
      final orders = FakeOrderRepository();
      final id = await placeTestOrder(orders, uid: 'u1');
      final order = orders.all.firstWhere((o) => o.id == id);
      final incidents = FakeIncidentRepository();
      await incidents.report(order: order, type: IncidentType.missingItem, description: 'Thiếu trà');
      final vm = SellerIncidentsViewModel(
        incidents: incidents,
        orders: orders,
        crash: FakeCrashService(),
        kioskId: 'q9-t2',
        staffUid: 'staff-1',
      );
      await pumpEventQueue();
      return (vm, incidents, order);
    }

    test('lists the reports of the kiosk with the order each is about', () async {
      final (vm, _, order) = await setUp();
      final incident = (vm.state as ViewData<List<Incident>>).data.single;
      expect(vm.orderOf(incident)?.id, order.id);
      expect(vm.maxRefundOf(incident), order.totalVnd);
      expect(vm.openCount, 1);
    });

    test('take, refund the order and the customer sees it resolved', () async {
      final (vm, incidents, order) = await setUp();
      final incident = incidents.all.single;
      expect(await vm.take(incident), isA<Ok<void>>());
      expect(incidents.all.single.status, IncidentStatus.inProgress);
      expect(await vm.refund(incidents.all.single), isA<Ok<void>>());
      await pumpEventQueue();
      final done = incidents.all.single;
      expect(
        (done.status, done.resolution, done.refundVnd),
        (IncidentStatus.resolved, IncidentResolution.refunded, order.totalVnd),
      );
      expect(vm.openCount, 0);
      expect(await vm.refund(done), isA<Err<void>>(), reason: 'already answered');
    });

    test('a refund above what was paid, or a rejection without a reason, is refused', () async {
      final (vm, incidents, order) = await setUp();
      final incident = incidents.all.single;
      expect(await vm.refund(incident, amountVnd: order.totalVnd + 1), isA<Err<void>>());
      expect(await vm.refund(incident, amountVnd: 0), isA<Err<void>>());
      expect(await vm.rejectReport(incident, '  '), isA<Err<void>>());
      expect(incidents.all.single.status, IncidentStatus.open);
      expect(await vm.rejectReport(incident, 'Đã kiểm tra đủ món'), isA<Ok<void>>());
      expect(
        (incidents.all.single.resolution, incidents.all.single.resolutionNote),
        (IncidentResolution.rejected, 'Đã kiểm tra đủ món'),
      );
    });

    test('a kiosk-less account sees the explanation', () async {
      final vm = SellerIncidentsViewModel(
        incidents: FakeIncidentRepository(),
        orders: FakeOrderRepository(),
        crash: FakeCrashService(),
        kioskId: null,
        staffUid: 's',
      );
      expect((vm.state as ViewEmpty).message, SellerIncidentsViewModel.noKioskMessage);
    });
  });

  group('sortIncidentsForStaff', () {
    test('open first, then in progress, then answered; newest first inside each', () {
      Incident make(String id, IncidentStatus status, int minute) => Incident(
        orderId: id,
        kioskId: 'k',
        uid: 'u',
        type: IncidentType.other,
        description: 'd',
        status: status,
        createdAt: DateTime(2026, 11, 2, 10, minute),
      );
      final sorted = sortIncidentsForStaff([
        make('a', IncidentStatus.resolved, 5),
        make('b', IncidentStatus.open, 1),
        make('c', IncidentStatus.inProgress, 9),
        make('d', IncidentStatus.open, 3),
      ]);
      expect(sorted.map((i) => i.orderId), ['d', 'b', 'c', 'a']);
    });
  });
}
