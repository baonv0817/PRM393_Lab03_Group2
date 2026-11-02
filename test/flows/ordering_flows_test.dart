import 'package:breakbite/app.dart';
import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fake_dependencies.dart';
import '../../dev/fakes/fakes.dart';
import '../helpers/orders.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Future<AppDependencies> openSignedIn(WidgetTester tester, {Size size = const Size(412, 915)}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final deps = createFakeDependencies(signedIn: true);
  await tester.pumpWidget(BreakBiteApp(dependencies: deps));
  await tester.pumpAndSettle();
  return deps;
}

Future<void> tapId(WidgetTester tester, String id) async {
  if (byId(id).evaluate().isEmpty) {
    await tester.scrollUntilVisible(byId(id), 120, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(byId(id));
  await tester.pumpAndSettle();
  await tester.tap(byId(id));
  await tester.pumpAndSettle();
}

Future<void> addTacosAndOpenCheckout(WidgetTester tester) async {
  await tapId(tester, 's02.item.m1.add');
  await tapId(tester, 's02.cart');
  expect(byId('s05.item.m1'), findsOneWidget);
  expect(find.text('39.000đ'), findsWidgets);
  await tapId(tester, 's05.checkout');
  expect(byId('s06.amount'), findsOneWidget);
}

String tomorrowSlotId(int hour, int minute) {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day + 1, hour, minute);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${day.year}${two(day.month)}${two(day.day)}-${two(hour)}${two(minute)}';
}

void main() {
  for (final size in const [Size(360, 800), Size(412, 915)]) {
    testWidgets(
      'F2 at ${size.width.round()} dp: Menu → item with a note → cart → voucher, an invalid voucher is caught, '
      'pickup slot → order',
      (tester) async {
        final deps = await openSignedIn(tester, size: size);
        await tester.tap(find.text('Thực đơn'));
        await tester.pumpAndSettle();
        expect(byId('s03.search'), findsOneWidget);

        await tester.tap(find.text('Combo Tacos Bò Phô Mai'));
        await tester.pumpAndSettle();
        expect(byId('s04.add'), findsOneWidget);
        await tapId(tester, 's04.quantity.inc');
        await tester.enterText(byId('s04.note'), 'Ít cay');
        await tester.pumpAndSettle();
        expect(find.text('Thêm vào giỏ · 78.000đ'), findsOneWidget);
        await tapId(tester, 's04.add');
        expect(byId('s03.search'), findsOneWidget);
        expect(find.text('Đã thêm 2 × Combo Tacos Bò Phô Mai vào giỏ'), findsOneWidget);
        final line = (deps.cart as FakeCartRepository).current('dev-user').items.single;
        expect((line.quantity, line.note), (2, 'Ít cay'));

        await tapId(tester, 's03.cart');
        await tapId(tester, 's05.voucher');
        expect(find.text('Mã của bạn'), findsOneWidget);
        await tapId(tester, 's29.voucher.BBSTUDENT');
        await tapId(tester, 's29.use');
        expect(find.text('BBSTUDENT · −10.000đ'), findsOneWidget);
        expect(find.text('68.000đ'), findsWidgets);

        await tapId(tester, 's05.item.m1.dec');
        expect(find.text('Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT.'), findsOneWidget);
        await tapId(tester, 's05.voucher.remove');
        expect(find.text('Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT.'), findsNothing);
        expect((deps.cart as FakeCartRepository).current('dev-user').voucherCode, isNull);

        await tapId(tester, 's05.pickup');
        final slotId = tomorrowSlotId(14, 45);
        await tapId(tester, 's25.slot.$slotId');
        await tapId(tester, 's25.confirm');
        expect(find.text('Hẹn nhận lúc 14:45'), findsOneWidget);

        await tapId(tester, 's05.checkout');
        await tapId(tester, 's06.method.cash');
        await tapId(tester, 's06.confirm');
        expect(byId('s07.header'), findsOneWidget);
        final order = (deps.orders as FakeOrderRepository).all.single;
        expect(order.pickupSlotId, slotId);
        expect(order.items.single.note, 'Ít cay');

        await tapId(tester, 's07.home');
        await tester.tap(find.text('Đơn hàng').last);
        await tester.pumpAndSettle();
        expect(find.text('Đang xử lý (1)'), findsOneWidget);
        expect(byId('s08.order.${order.id}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'F1 at ${size.width.round()} dp: Home → cart → checkout → gateway → order tracking, the cart is emptied',
      (tester) async {
        final deps = await openSignedIn(tester, size: size);
        await addTacosAndOpenCheckout(tester);
        expect(find.text('Xác nhận đặt đơn · 39.000đ'), findsOneWidget);

        await tapId(tester, 's06.confirm');
        expect(find.text('Mô phỏng cổng thanh toán bên thứ ba'), findsOneWidget);
        expect(find.textContaining(RegExp(r'^0[45]:[0-5][0-9]$')), findsOneWidget);

        await tapId(tester, 's06g.pay');
        expect(byId('s07.header'), findsOneWidget);
        expect(find.text('#A-204'), findsOneWidget);
        expect(find.text('Chờ kiosk nhận đơn'), findsOneWidget);
        expect(byId('s07.qr'), findsOneWidget);
        expect(find.text('Tổng 39.000đ · Đã thanh toán Ví MoMo'), findsOneWidget);

        final order = (deps.orders as FakeOrderRepository).all.single;
        expect(order.paymentStatus, PaymentStatus.paid);
        expect((deps.cart as FakeCartRepository).current('dev-user').isEmpty, isTrue);
        final events = (deps.analytics as FakeAnalyticsService).events.map((e) => e.name);
        expect(events, containsAllInOrder(['add_to_cart', 'begin_checkout', 'purchase']));
      },
    );

    testWidgets(
      'F3 at ${size.width.round()} dp: declined at the gateway keeps the cart, cash at the kiosk, then cancelled',
      (tester) async {
        final deps = await openSignedIn(tester, size: size);
        await addTacosAndOpenCheckout(tester);
        await tapId(tester, 's06.confirm');
        await tapId(tester, 's06g.decline');

        expect(find.text('Thanh toán chưa thành công'), findsOneWidget);
        expect(find.text('Thanh toán Ví MoMo thất bại'), findsOneWidget);
        expect(byId('s06.kept'), findsOneWidget);
        expect(byId('s06.method.momo'), findsNothing);
        expect(find.text('Thử lại với VNPAY-QR'), findsOneWidget);
        expect((deps.cart as FakeCartRepository).current('dev-user').items, hasLength(1));
        expect((deps.analytics as FakeAnalyticsService).events.map((e) => e.name), contains('payment_failed'));

        await tapId(tester, 's06.method.cash');
        expect(find.text('Đặt đơn, trả tiền mặt tại kiosk'), findsOneWidget);
        await tapId(tester, 's06.confirm');

        expect(byId('s07.header'), findsOneWidget);
        expect(find.text('Trả tại quầy'), findsOneWidget);
        expect(find.text('Trả tại quầy khi nhận: 39.000đ'), findsOneWidget);
        expect((deps.orders as FakeOrderRepository).all.single.paymentStatus, PaymentStatus.unpaid);

        await tapId(tester, 's07.cancel');
        expect(find.text('Huỷ đơn #A-204?'), findsOneWidget);
        await tester.tap(find.text('Huỷ đơn').last);
        await tester.pumpAndSettle();
        expect(byId('s10.header'), findsOneWidget);
        expect(find.text('#A-204'), findsOneWidget);
        expect(find.text('Bạn đã huỷ đơn này.'), findsOneWidget);
        expect(find.text('Bạn chưa trả tiền cho đơn này nên không có khoản nào cần hoàn.'), findsOneWidget);
        expect(find.text('Combo Tacos Bò Phô Mai ×1'), findsOneWidget);

        await tapId(tester, 's10.reorder');
        expect(find.text('Đã thêm 1 món vào giỏ'), findsOneWidget);
        expect((deps.cart as FakeCartRepository).current('dev-user').items, hasLength(1));
        await tester.tap(find.byTooltip('Đóng'));
        await tester.pumpAndSettle();
        expect(find.text('Món nhanh · tối đa 5 phút'), findsOneWidget);
        expect((deps.orders as FakeOrderRepository).all.single.status, OrderStatus.cancelled);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('leaving the gateway with Back counts as a failed payment and keeps the cart', (tester) async {
    final deps = await openSignedIn(tester);
    await addTacosAndOpenCheckout(tester);
    await tapId(tester, 's06.confirm');
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(byId('s06.error'), findsOneWidget);
    expect(find.text('Bạn đã rời cổng thanh toán trước khi xác nhận.'), findsOneWidget);
    expect((deps.orders as FakeOrderRepository).all, isEmpty);
  });

  testWidgets('the cart edits quantities and notes; emptying it shows the empty state', (tester) async {
    final deps = await openSignedIn(tester);
    await tapId(tester, 's02.item.m1.add');
    await tapId(tester, 's02.cart');
    await tapId(tester, 's05.item.m1.inc');
    expect(find.text('78.000đ'), findsWidgets);
    expect(find.text('Tạm tính (2 món)'), findsOneWidget);

    await tapId(tester, 's05.item.m1.note');
    await tester.enterText(byId('s05.noteField').first, 'Ít cay');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu ghi chú'));
    await tester.pumpAndSettle();
    expect(find.text('Ít cay'), findsOneWidget);
    expect((deps.cart as FakeCartRepository).current('dev-user').items.single.note, 'Ít cay');

    await tapId(tester, 's05.item.m1.dec');
    await tapId(tester, 's05.item.m1.dec');
    expect(byId('s05.empty'), findsOneWidget);
  });

  testWidgets('S08 opens a finished order in S12, which exports its receipt, then Back returns to the list', (
    tester,
  ) async {
    final deps = createFakeDependencies(signedIn: true);
    final orders = deps.orders as FakeOrderRepository;
    final id = await placeTestOrder(orders, uid: 'dev-user');
    Order current() => orders.all.firstWhere((o) => o.id == id);
    await orders.accept(current(), readyIn: const Duration(minutes: 5));
    await orders.markReady(current());
    await orders.deliver(current());
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BreakBiteApp(dependencies: deps));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đơn hàng').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('#$id'));
    await tester.pumpAndSettle();
    expect(byId('s12.header'), findsOneWidget);
    expect(find.text('Hoàn tất'), findsWidgets);

    await tapId(tester, 's12.export');
    await tester.scrollUntilVisible(byId('s12.export.card'), 120, scrollable: find.byType(Scrollable).first);
    expect(byId('s12.export.card'), findsOneWidget);
    final report = (deps.reports as FakeReportRepository).all.single;
    expect(report.orderId, id);
    expect(find.text(report.url), findsOneWidget);
    expect((deps.analytics as FakeAnalyticsService).events.map((e) => e.name), contains('export_report'));

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Đơn gần đây'), findsOneWidget);
  });

  testWidgets('S08 opens the full history (S11), an order there opens S12, and Back retraces the steps', (
    tester,
  ) async {
    final deps = createFakeDependencies(signedIn: true);
    final orders = deps.orders as FakeOrderRepository;
    final id = await placeTestOrder(orders, uid: 'dev-user');
    await orders.cancelMyOrder(orders.all.single);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BreakBiteApp(dependencies: deps));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đơn hàng').last);
    await tester.pumpAndSettle();

    await tapId(tester, 's08.tab.history');
    await tapId(tester, 's08.allHistory');
    expect(byId('s11.grouping.week'), findsOneWidget);
    expect(byId('s11.order.$id'), findsOneWidget);

    await tester.tap(byId('s11.grouping.month'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tháng'), findsOneWidget);

    await tapId(tester, 's11.order.$id');
    expect(byId('s12.header'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(byId('s11.grouping.week'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(byId('s08.tab.history'), findsOneWidget);
  });

  testWidgets('S08 reorders a finished order into the cart and the snackbar opens it', (tester) async {
    final deps = createFakeDependencies(signedIn: true);
    final orders = deps.orders as FakeOrderRepository;
    final id = await placeTestOrder(orders, uid: 'dev-user');
    await orders.cancelMyOrder(orders.all.single);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BreakBiteApp(dependencies: deps));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đơn hàng').last);
    await tester.pumpAndSettle();
    await tapId(tester, 's08.order.$id.reorder');
    expect(find.text('Đã thêm 1 món vào giỏ'), findsOneWidget);
    await tester.tap(find.text('Xem giỏ'));
    await tester.pumpAndSettle();
    expect(byId('s05.item.m1'), findsOneWidget);
  });
}
