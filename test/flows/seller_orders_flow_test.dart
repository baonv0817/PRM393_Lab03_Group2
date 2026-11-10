import 'package:breakbite/app.dart';
import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fake_dependencies.dart';
import '../../dev/fakes/fakes.dart';
import '../helpers/orders.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Future<void> tapId(WidgetTester tester, String id) async {
  await tester.ensureVisible(byId(id));
  await tester.pumpAndSettle();
  await tester.tap(byId(id));
  await tester.pumpAndSettle();
}

Future<AppDependencies> openAsStaff(WidgetTester tester, {Size size = const Size(412, 2000)}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final deps = createFakeDependencies(role: UserRole.staff, signedIn: true);
  return deps;
}

Future<void> start(WidgetTester tester, AppDependencies deps) async {
  await tester.pumpWidget(BreakBiteApp(dependencies: deps));
  await tester.pumpAndSettle();
}

Order _find(AppDependencies deps, String id) => (deps.orders as FakeOrderRepository).all.firstWhere((o) => o.id == id);

void main() {
  testWidgets('K02: a kiosk assigned while the app is open shows its orders without restarting the app', (
    tester,
  ) async {
    final deps = await openAsStaff(tester);
    final auth = deps.auth as FakeAuthService;
    auth.setKiosk(null);
    final id = await placeTestOrder(deps.orders as FakeOrderRepository, uid: 'u1');
    await start(tester, deps);

    expect(find.textContaining('chưa được gán kiosk'), findsOneWidget);
    expect(byId('k02.order.$id'), findsNothing);

    auth.setKiosk('q9-t2');
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa được gán kiosk'), findsNothing);
    expect(byId('k02.order.$id'), findsOneWidget);
  });

  testWidgets('K02 → K03 → K04 → K02 → K06: a staff member takes an order, makes it and hands it over', (tester) async {
    final deps = await openAsStaff(tester);
    final orders = deps.orders as FakeOrderRepository;
    final id = await placeTestOrder(
      orders,
      uid: 'u1',
      items: const [
        CartItem(itemId: 'm1', name: 'Combo Tacos', priceVnd: 39000, note: 'Cay vừa'),
        CartItem(itemId: 'm2', name: 'Trà Đào', priceVnd: 20000),
      ],
    );
    await start(tester, deps);

    expect(find.text('Đơn hôm nay'), findsOneWidget);
    expect(find.text('Mới (1)'), findsOneWidget);
    expect(byId('k02.order.$id'), findsOneWidget);

    await tapId(tester, 'k02.order.$id');
    expect(find.text('Đơn #$id'), findsOneWidget);
    expect(find.text('Cay vừa'), findsOneWidget);
    expect(byId('k03.reject'), findsOneWidget);
    await tapId(tester, 'k03.accept');

    expect(_find(deps, id).status, OrderStatus.preparing);
    expect(byId('k04.countdown'), findsOneWidget);
    // The fake orders run on their own clock, so the countdown may already be past: either text is right.
    expect(find.textContaining(RegExp('Còn |Trễ ')), findsOneWidget);
    await tapId(tester, 'k04.line.0');
    await tapId(tester, 'k04.line.1');
    await tapId(tester, 'k04.ready');

    expect(find.text('Đã báo khách: món sẵn sàng.'), findsOneWidget);
    expect(_find(deps, id).status, OrderStatus.ready);
    expect(find.text('Sẵn sàng (1)'), findsOneWidget);
    await tapId(tester, 'k02.tab.ready');
    await tapId(tester, 'k02.open.$id');
    expect(find.text('Mã hợp lệ · #$id'), findsOneWidget);
    await tapId(tester, 'k06.confirm');

    expect(find.text('Đã giao món.'), findsOneWidget);
    expect(_find(deps, id).status, OrderStatus.delivered);
    expect(find.text('Sẵn sàng (0)'), findsOneWidget);
  });

  testWidgets('K02 "Nhận đơn" starts an order from the list and shows which orders are paid at the counter', (
    tester,
  ) async {
    final deps = await openAsStaff(tester);
    final orders = deps.orders as FakeOrderRepository;
    final momo = await placeTestOrder(orders, uid: 'u1');
    final cash = await placeTestOrder(orders, uid: 'u2', method: PaymentMethod.cash);
    await start(tester, deps);

    expect(find.textContaining('Đã thanh toán Ví MoMo'), findsOneWidget);
    expect(find.textContaining('Trả tại quầy 39.000đ'), findsOneWidget);
    await tapId(tester, 'k02.accept.$cash');
    expect(_find(deps, cash).status, OrderStatus.preparing);
    expect(_find(deps, momo).status, OrderStatus.pending);
    expect(find.text('Mới (1)'), findsOneWidget);
    expect(find.text('Đang làm (1)'), findsOneWidget);
  });

  testWidgets('K03 → K12: turning an order down needs a reason and refunds the customer', (tester) async {
    final deps = await openAsStaff(tester);
    final id = await placeTestOrder(deps.orders as FakeOrderRepository, uid: 'u1');
    await start(tester, deps);

    await tapId(tester, 'k02.order.$id');
    await tapId(tester, 'k03.reject');
    expect(find.text('Từ chối đơn #$id?'), findsOneWidget);
    expect(find.text('Khách được hoàn tiền tự động.'), findsOneWidget);

    await tapId(tester, 'k12.reason.other');
    await tapId(tester, 'k12.reject');
    expect(find.text('Nhập lý do để khách biết.'), findsOneWidget, reason: '"other" needs a typed reason');
    await tester.enterText(find.descendant(of: byId('k12.text'), matching: find.byType(TextField)), 'Hỏng bếp');
    await tapId(tester, 'k12.reject');

    expect(find.text('Đã từ chối đơn. Khách được hoàn tiền tự động.'), findsOneWidget);
    final order = _find(deps, id);
    expect(
      (order.status, order.cancelledBy, order.cancelReason),
      (OrderStatus.cancelled, CancelledBy.staff, 'Hỏng bếp'),
    );
  });

  testWidgets('K04 "Báo thiếu nguyên liệu" turns the order down with the reason "Hết món"', (tester) async {
    final deps = await openAsStaff(tester);
    final orders = deps.orders as FakeOrderRepository;
    final id = await placeTestOrder(orders, uid: 'u1');
    await orders.accept(_find(deps, id), readyIn: const Duration(minutes: 5));
    await start(tester, deps);

    await tapId(tester, 'k02.tab.preparing');
    await tapId(tester, 'k02.open.$id');
    await tapId(tester, 'k04.shortage');
    await tapId(tester, 'k12.reject');

    expect(_find(deps, id).cancelReason, 'Hết món');
  });

  testWidgets('K05 → K06-CASH: the pickup code opens the order, cash is collected, a wrong code shows K05-ERR', (
    tester,
  ) async {
    final deps = await openAsStaff(tester);
    final orders = deps.orders as FakeOrderRepository;
    final id = await placeTestOrder(orders, uid: 'u1', method: PaymentMethod.cash);
    await orders.accept(_find(deps, id), readyIn: const Duration(minutes: 3));
    await orders.markReady(_find(deps, id));
    final code = _find(deps, id).pickupCode;
    await start(tester, deps);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Quét mã')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: byId('k05.input'), matching: find.byType(TextField)), '#A-999');
    await tapId(tester, 'k05.find');
    expect(byId('k05.error'), findsOneWidget);
    expect(find.text('Mã không hợp lệ hoặc đã hết hạn'), findsOneWidget);

    await tester.enterText(find.descendant(of: byId('k05.input'), matching: find.byType(TextField)), code);
    await tester.pump();
    expect(byId('k05.error'), findsNothing, reason: 'editing clears the error');
    await tapId(tester, 'k05.find');
    expect(byId('k06.cash'), findsOneWidget);
    expect(find.text('Thu tiền mặt 39.000đ'), findsOneWidget);
    await tapId(tester, 'k06.cash.confirm');

    expect(find.text('Đã thu tiền và giao món.'), findsOneWidget);
    expect(_find(deps, id).status, OrderStatus.delivered);
    expect(_find(deps, id).paymentStatus, PaymentStatus.paid);
  });

  testWidgets('K02 bell → K13: a customer report is taken on and refunded, and the customer sees the answer', (
    tester,
  ) async {
    final deps = await openAsStaff(tester);
    final orders = deps.orders as FakeOrderRepository;
    final incidents = deps.incidents as FakeIncidentRepository;
    final id = await placeTestOrder(orders, uid: 'u1');
    await incidents.report(order: _find(deps, id), type: IncidentType.missingItem, description: 'Thiếu trà đào');
    await start(tester, deps);

    await tapId(tester, 'k02.incidents');
    expect(find.text('Sự cố từ khách'), findsOneWidget);
    expect(find.text('"Thiếu trà đào"'), findsOneWidget);

    await tapId(tester, 'k13.take.$id');
    expect(incidents.all.single.status, IncidentStatus.inProgress);
    await tapId(tester, 'k13.refund.$id');
    await tester.tap(find.text('Hoàn tiền').last);
    await tester.pumpAndSettle();

    expect(find.text('Đã hoàn 39.000đ cho khách.'), findsOneWidget);
    final done = incidents.all.single;
    expect(
      (done.status, done.resolution, done.refundVnd, done.handledBy),
      (IncidentStatus.resolved, IncidentResolution.refunded, 39000, 'staff-1'),
    );
    expect(byId('k13.refund.$id'), findsNothing, reason: 'an answered report has no buttons');
  });

  testWidgets('K13: a report is turned down with a reason the customer reads', (tester) async {
    final deps = await openAsStaff(tester);
    final orders = deps.orders as FakeOrderRepository;
    final incidents = deps.incidents as FakeIncidentRepository;
    final id = await placeTestOrder(orders, uid: 'u1');
    await incidents.report(order: _find(deps, id), type: IncidentType.quality, description: 'Món nguội');
    await start(tester, deps);

    await tapId(tester, 'k02.incidents');
    await tapId(tester, 'k13.reject.$id');
    await tapId(tester, 'k13.reason.send');
    expect(find.text('Nhập lý do để khách biết.'), findsOneWidget);
    await tester.enterText(
      find.descendant(of: byId('k13.reason'), matching: find.byType(TextField)),
      'Đã kiểm tra, món vừa ra',
    );
    await tapId(tester, 'k13.reason.send');

    final done = incidents.all.single;
    expect((done.resolution, done.resolutionNote), (IncidentResolution.rejected, 'Đã kiểm tra, món vừa ra'));
    expect(find.text('Lý do: Đã kiểm tra, món vừa ra'), findsOneWidget);
  });

  testWidgets('K02-EMPTY and K13 empty: nothing to do yet', (tester) async {
    final deps = await openAsStaff(tester);
    await start(tester, deps);
    expect(byId('k02.emptyTab'), findsOneWidget);
    expect(find.textContaining('Đơn mới sẽ hiện ở đây'), findsOneWidget);
    await tapId(tester, 'k02.incidents');
    expect(byId('k13.empty'), findsOneWidget);
  });
}
