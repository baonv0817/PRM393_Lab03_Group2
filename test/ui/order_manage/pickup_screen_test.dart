import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/order_manage/view_models/pickup_view_model.dart';
import 'package:breakbite/ui/order_manage/widgets/pickup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

class _NeverLoads extends FakeOrderRepository {
  @override
  Stream<Order?> watchOrder(String id) => const Stream.empty();
}

class _FailingOrders extends FakeOrderRepository {
  @override
  Stream<Order?> watchOrder(String id) => Stream.error(const NetworkException());
}

Future<void> _pump(
  WidgetTester tester,
  FakeOrderRepository orders,
  String orderId, {
  Size size = TestScreens.narrow,
  bool settle = true,
}) async {
  // The width is the phone's; the height is tall because a ListView only builds what is on screen and
  // the test font is wider than Nunito, so the whole page would otherwise need scrolling.
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(size.width, 3200);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: AppRoutes.orderPickupOf(orderId),
    routes: [
      GoRoute(
        path: AppRoutes.orderPickup,
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) =>
              PickupViewModel(orders: orders, crash: FakeCrashService(), orderId: state.pathParameters['id']!),
          child: const PickupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.orderDetail,
        builder: (context, state) => Scaffold(body: Text('S12 ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: AppRoutes.order,
        builder: (context, state) => Scaffold(body: Text('S07 ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => const Scaffold(body: Text('ORDERS')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(theme: AppTheme.light(), routerConfig: router));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S20 at ${size.width.round()} dp shows the QR code, the code in two groups and what to do', (
      tester,
    ) async {
      final orders = FakeOrderRepository();
      final id = await placeTestOrder(orders, uid: 'u1');
      await _pump(tester, orders, id, size: size);

      expect(byId('s20.qr'), findsOneWidget);
      expect(find.text('Đơn #$id · Kiosk'), findsOneWidget);
      expect(find.text('100 204'), findsOneWidget);
      expect(find.text('Kiosk chưa nhận đơn. Mã dùng được khi món sẵn sàng.'), findsOneWidget);
      expect(find.text('Combo ×1 · 39.000đ'), findsOneWidget);
      expect(byId('s20.unavailable'), findsNothing);
      expect(byId('s20.detail'), findsNothing);
      expect(byId('s20.payment'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S20 of a cash order reminds the amount to pay at the counter', (tester) async {
    final orders = FakeOrderRepository();
    final id = await placeTestOrder(orders, uid: 'u1', method: PaymentMethod.cash);
    await _pump(tester, orders, id);

    expect(byId('s20.payment'), findsOneWidget);
    expect(find.text('Trả tại quầy khi nhận: 39.000đ'), findsOneWidget);
  });

  testWidgets('S20 follows the order: the message changes when it is ready, and the code is spent once delivered', (
    tester,
  ) async {
    final orders = FakeOrderRepository();
    final id = await placeTestOrder(orders, uid: 'u1');
    await _pump(tester, orders, id);

    await orders.accept(orders.all.single, readyIn: const Duration(minutes: 5));
    await orders.markReady(orders.all.single);
    await tester.pumpAndSettle();
    expect(find.text('Món đã sẵn sàng. Đưa mã này cho kiosk.'), findsOneWidget);
    expect(byId('s20.qr'), findsOneWidget);

    await orders.deliver(orders.all.single);
    await tester.pumpAndSettle();
    expect(byId('s20.qr'), findsNothing);
    expect(byId('s20.unavailable'), findsOneWidget);
    expect(find.text('Mã này đã hết hiệu lực'), findsOneWidget);
    expect(find.textContaining('Bạn đã nhận món lúc'), findsOneWidget);
  });

  testWidgets('S20 of a cancelled order shows no QR code and a way to the order detail', (tester) async {
    final orders = FakeOrderRepository();
    final id = await placeTestOrder(orders, uid: 'u1');
    await orders.cancelMyOrder(orders.all.single);
    await _pump(tester, orders, id);

    expect(byId('s20.qr'), findsNothing);
    expect(find.text('Đơn đã huỷ nên mã không còn dùng được.'), findsOneWidget);
    await tester.tap(byId('s20.detail'));
    await tester.pumpAndSettle();
    expect(find.text('S12 $id'), findsOneWidget);
  });

  testWidgets('S20 close and the back button return to the order when it was opened without a history', (tester) async {
    final orders = FakeOrderRepository();
    final id = await placeTestOrder(orders, uid: 'u1');
    await _pump(tester, orders, id);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('S07 $id'), findsOneWidget);

    final other = FakeOrderRepository();
    final otherId = await placeTestOrder(other, uid: 'u1');
    await _pump(tester, other, otherId);
    await tester.tap(byId('s20.close'));
    await tester.pumpAndSettle();
    expect(find.text('S07 $otherId'), findsOneWidget);
  });

  testWidgets('S20 shows the loading state while the order has not arrived', (tester) async {
    await _pump(tester, _NeverLoads(), 'A-204', settle: false);
    expect(find.text('Đang tải đơn hàng…'), findsOneWidget);
  });

  testWidgets('S20 shows an error with a retry when the order cannot be loaded', (tester) async {
    await _pump(tester, _FailingOrders(), 'A-204');
    expect(byId('s20.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('S20 shows the empty state for an unknown order and goes to the orders list', (tester) async {
    await _pump(tester, FakeOrderRepository(), 'nope');
    expect(byId('s20.empty'), findsOneWidget);
    expect(find.text('Không tìm thấy đơn này.'), findsOneWidget);
    await tester.tap(find.text('Xem đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.text('ORDERS'), findsOneWidget);
  });
}
