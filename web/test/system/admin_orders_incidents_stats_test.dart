import 'package:breakbite_admin/ui/system/incidents/view_models/admin_incidents_view_model.dart';
import 'package:breakbite_admin/ui/system/orders/view_models/admin_orders_view_model.dart';
import 'package:breakbite_admin/ui/system/stats/view_models/admin_stats_view_model.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_menu_repository.dart';
import 'fakes/system_fakes.dart';
import 'harness.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

// Wednesday 11 November 2026, midday in Vietnam.
final _now = DateTime.utc(2026, 11, 11, 5);

Order _order(
  String id,
  Duration age, {
  String kiosk = 'q9-t2',
  OrderStatus status = OrderStatus.delivered,
  int total = 40000,
}) => Order(
  id: id,
  uid: 'u',
  orderCode: id.toUpperCase(),
  customerName: 'Khách $id',
  kioskId: kiosk,
  kioskName: kiosk,
  items: const [CartItem(itemId: 'm', name: 'Combo', priceVnd: 40000)],
  totalVnd: total,
  paymentMethod: PaymentMethod.momo,
  status: status,
  createdAt: _now.subtract(age),
);

void main() {
  group('AdminOrdersViewModel (A06)', () {
    AdminOrdersViewModel makeVm(FakeAdminOrderRepository repo) =>
        AdminOrdersViewModel(orders: repo, menu: FakeMenuRepository(), clock: () => _now);

    test('lists the orders of the last week, newest first, from every kiosk', () async {
      final repo = FakeAdminOrderRepository(now: _now);
      final vm = makeVm(repo);
      await pumpEventQueue();
      final orders = vm.state.dataOrNull!;
      expect(orders.map((o) => o.id), ['o2', 'o1', 'o3', 'o4', 'o5', 'o6', 'o7']);
      expect({for (final o in orders) o.kioskId}, {'q9-t2', 'q9-t4'});
      vm.dispose();
    });

    test('filters by kiosk, by state and by period, and each change reads the list again', () async {
      final vm = makeVm(FakeAdminOrderRepository(now: _now));
      await pumpEventQueue();

      vm.setKiosk('q9-t4');
      await pumpEventQueue();
      expect(vm.state.dataOrNull!.every((o) => o.kioskId == 'q9-t4'), isTrue);
      vm.setKiosk(null);

      vm.setStatus(OrderStatus.cancelled);
      await pumpEventQueue();
      expect(vm.state.dataOrNull!.single.id, 'o5');
      vm.setStatus(null);

      vm.setRange(OrderRange.today);
      await pumpEventQueue();
      expect(vm.state.dataOrNull!.map((o) => o.id), ['o2', 'o1', 'o3', 'o4'], reason: 'the orders of today in Vietnam');
      vm.setRange(OrderRange.all);
      await pumpEventQueue();
      expect(vm.state.dataOrNull, hasLength(7));
      vm.dispose();
    });

    test('an order that nobody accepted for 15 minutes is stuck, and "Đơn kẹt" shows only those', () async {
      final repo = FakeAdminOrderRepository(now: _now);
      final vm = makeVm(repo);
      await pumpEventQueue();
      final o1 = repo.orders.firstWhere((o) => o.id == 'o1');
      expect(vm.isStuck(o1), isTrue, reason: 'pending for 40 minutes');
      expect(vm.isStuck(repo.orders.firstWhere((o) => o.id == 'o2')), isFalse, reason: 'preparing');
      expect(vm.stuckCount, 1);

      vm.setStuckOnly(true);
      await pumpEventQueue();
      expect(vm.visible.map((o) => o.id), ['o1']);
      vm.setStatus(OrderStatus.delivered);
      expect(vm.stuckOnly, isFalse, reason: 'choosing a state leaves "stuck"');
      vm.dispose();
    });

    test('the search box finds an order by its code or the name of the customer, without accents', () async {
      final repo = FakeAdminOrderRepository(
        orders: [_order('a1', Duration.zero), _order('b2', const Duration(hours: 1))],
        now: _now,
      );
      final vm = makeVm(repo);
      await pumpEventQueue();
      vm.setSearch('b2');
      expect(vm.visible.single.id, 'b2');
      vm.setSearch('KHACH a1');
      expect(vm.visible.single.id, 'a1');
      vm.setSearch('nope');
      expect(vm.visible, isEmpty);
      vm.dispose();
    });

    test('pages through a long list: "Tải thêm" adds the next orders and stops at the end', () async {
      final repo = FakeAdminOrderRepository(
        orders: [for (var i = 0; i < 30; i++) _order('p$i', Duration(minutes: i + 1))],
        now: _now,
      );
      final vm = makeVm(repo);
      await pumpEventQueue();
      expect(vm.state.dataOrNull, hasLength(AdminOrdersViewModel.pageSize));
      expect(vm.hasMore, isTrue);

      await vm.loadMore();
      expect(vm.state.dataOrNull, hasLength(30));
      expect(vm.hasMore, isFalse);
      expect(vm.state.dataOrNull!.map((o) => o.id).toSet(), hasLength(30), reason: 'no order twice');
      vm.dispose();
    });

    test('an empty filter says so; a failed read is an error with retry; a failed page keeps the list', () async {
      final repo = FakeAdminOrderRepository(orders: const [], now: _now);
      final vm = makeVm(repo);
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<List<Order>>>());

      repo.failNext = const NetworkException();
      await vm.load();
      expect(vm.state, isA<ViewError<List<Order>>>());
      vm.dispose();

      final many = FakeAdminOrderRepository(
        orders: [for (var i = 0; i < 30; i++) _order('p$i', Duration(minutes: i + 1))],
        now: _now,
      );
      final paged = makeVm(many);
      await pumpEventQueue();
      many.failNext = const NetworkException();
      await paged.loadMore();
      expect(paged.state.dataOrNull, hasLength(25), reason: 'the first page stays');
      expect(paged.moreError, isNotNull);
      expect(paged.hasMore, isTrue, reason: 'it can be tried again');
      paged.dispose();
    });
  });

  group('AdminIncidentsViewModel (A07)', () {
    AdminIncidentsViewModel makeVm(FakeAdminIncidentRepository repo) =>
        AdminIncidentsViewModel(incidents: repo, menu: FakeMenuRepository(), clock: () => _now);

    test('puts the open reports first, filters by state and kiosk, and counts what is overdue', () async {
      final repo = FakeAdminIncidentRepository(now: _now);
      final vm = makeVm(repo);
      await pumpEventQueue();
      expect(vm.visible.map((i) => i.orderId), ['o3', 'o4'], reason: 'open before answered');
      expect((vm.countOf(IncidentStatus.open), vm.countOf(IncidentStatus.resolved)), (1, 1));

      vm.setStatus(IncidentStatus.resolved);
      expect(vm.visible.single.refundVnd, 30000);
      vm.setStatus(null);
      vm.setKiosk('q9-t2');
      expect(vm.visible.single.orderId, 'o3');
      expect(vm.overdue, 0, reason: 'the open one is only two hours old');

      repo.add(
        Incident(
          orderId: 'o9',
          kioskId: 'q9-t2',
          uid: 'u',
          type: IncidentType.late,
          description: 'Chờ lâu',
          status: IncidentStatus.open,
          createdAt: _now.subtract(const Duration(days: 2)),
        ),
      );
      await pumpEventQueue();
      expect(vm.overdue, 1);
      vm.dispose();
    });

    test('says when nobody has reported anything', () async {
      final vm = makeVm(FakeAdminIncidentRepository(incidents: const [], now: _now));
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<List<Incident>>>());
      vm.dispose();
    });
  });

  group('AdminStatsViewModel (A08)', () {
    AdminStatsViewModel makeVm(FakeAdminOrderRepository repo) =>
        AdminStatsViewModel(orders: repo, menu: FakeMenuRepository(), clock: () => _now);

    test('works out the figures of the last seven days for every kiosk', () async {
      final vm = makeVm(FakeAdminOrderRepository(now: _now));
      await pumpEventQueue();
      final report = vm.state.dataOrNull!;
      expect(report.orders, 7);
      expect(report.delivered, 4);
      expect(report.revenueVnd, 40000 + 60000 + 40000 + 20000);
      expect(report.byKiosk.map((k) => k.kioskId), containsAll(['q9-t2', 'q9-t4']));
      vm.dispose();
    });

    test('a shorter period or one kiosk reads again and narrows the figures', () async {
      final repo = FakeAdminOrderRepository(now: _now);
      final vm = makeVm(repo);
      await pumpEventQueue();
      vm.setKiosk('q9-t4');
      await pumpEventQueue();
      expect(vm.state.dataOrNull!.byKiosk.single.kioskId, 'q9-t4');
      vm.setKiosk(null);
      vm.setDays(14);
      expect(vm.days, 14);
      expect(vm.period.to.difference(vm.period.from), const Duration(days: 14));
      vm.dispose();
    });

    test('the period runs from 00:00 of the first day to the end of today, Vietnam time', () async {
      final vm = makeVm(FakeAdminOrderRepository(now: _now));
      await pumpEventQueue();
      expect(vm.period.from, DateTime.utc(2026, 11, 4, 17), reason: '00:00 on the 5th in Vietnam, 7 days back');
      expect(vm.period.to, DateTime.utc(2026, 11, 11, 17), reason: '00:00 on the 12th in Vietnam');
      vm.dispose();
    });

    test('also reads the period before and gives the change against it, none when it had no orders', () async {
      final repo = FakeAdminOrderRepository(
        orders: [
          _order('n1', const Duration(days: 1), total: 60000),
          _order('n2', const Duration(days: 2), total: 40000),
          _order('p1', const Duration(days: 9), total: 50000),
        ],
        now: _now,
      );
      final vm = makeVm(repo);
      await pumpEventQueue();
      expect(vm.state.dataOrNull!.revenueVnd, 100000);
      expect(vm.previous?.revenueVnd, 50000);
      expect(AdminStatsViewModel.change(100000, 50000), 1.0);
      expect(AdminStatsViewModel.change(10, 0), isNull);

      vm.setDays(14);
      await pumpEventQueue();
      expect(vm.previous, isNull, reason: 'nothing was ordered in the 14 days before');
      vm.dispose();
    });

    test('an empty period, a failed read and a period with too many orders are each said', () async {
      final empty = makeVm(FakeAdminOrderRepository(orders: const [], now: _now));
      await pumpEventQueue();
      expect(empty.state, isA<ViewEmpty<SalesReport>>());
      empty.dispose();

      final repo = FakeAdminOrderRepository(now: _now)..failNext = const NetworkException();
      final failing = makeVm(repo);
      await pumpEventQueue();
      expect(failing.state, isA<ViewError<SalesReport>>());
      failing.dispose();
    });
  });

  group('A06, A07 and A08 on screen', () {
    Future<void> open(WidgetTester tester, String page) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1500, 1600);
      addTearDown(tester.view.reset);
      await pumpSystemApp(tester);
      await goToPage(tester, page);
    }

    testWidgets('A06 lists the orders, flags the stuck one, and opens the detail of an order', (tester) async {
      await open(tester, 'Đơn hàng');
      expect(byId('a06.row.o1'), findsOneWidget);
      expect(find.textContaining('Kẹt'), findsWidgets);

      await tester.tap(byId('a06.row.o3'));
      await tester.pumpAndSettle();
      expect(byId('a06.detail'), findsOneWidget);
      expect(find.text('Combo Tacos Bò Phô Mai ×1'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(byId('a06.detail'), findsNothing);
    });

    testWidgets('A06 filters: a state chip and "Đơn kẹt" narrow the list', (tester) async {
      await open(tester, 'Đơn hàng');
      await tester.tap(byId('a06.status.cancelled'));
      await tester.pumpAndSettle();
      expect(byId('a06.row.o5'), findsOneWidget);
      expect(byId('a06.row.o3'), findsNothing);

      await tester.tap(byId('a06.stuck'));
      await tester.pumpAndSettle();
      expect(byId('a06.row.o1'), findsOneWidget);
      expect(byId('a06.row.o2'), findsNothing);
    });

    testWidgets('A07 shows the reports with their answer, and the state chips narrow them', (tester) async {
      await open(tester, 'Sự cố');
      expect(byId('a07.row.o3'), findsOneWidget);
      expect(find.textContaining('Hoàn tiền'), findsWidgets);
      await tester.tap(byId('a07.status.open'));
      await tester.pumpAndSettle();
      expect(byId('a07.row.o3'), findsOneWidget);
      expect(byId('a07.row.o4'), findsNothing);
    });

    testWidgets('A08 shows takings, the days, the kiosks and the best sellers', (tester) async {
      await open(tester, 'Thống kê');
      expect(byId('a08.revenue'), findsOneWidget);
      expect(find.text('160.000đ'), findsWidgets);
      expect(byId('a08.days'), findsOneWidget);
      expect(byId('a08.kiosks'), findsOneWidget);
      expect(find.text('Combo Tacos Bò Phô Mai'), findsWidgets);

      await tester.tap(byId('a08.days.14'));
      await tester.pumpAndSettle();
      expect(byId('a08.revenue'), findsOneWidget);
    });
  });
}
