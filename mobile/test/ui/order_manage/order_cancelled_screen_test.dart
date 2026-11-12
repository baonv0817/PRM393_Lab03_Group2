import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/order_manage/view_models/order_cancelled_view_model.dart';
import 'package:breakbite/ui/order_manage/widgets/order_cancelled_screen.dart';
import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
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

class _Harness {
  _Harness({FakeOrderRepository? orders}) : orders = orders ?? FakeOrderRepository();

  final FakeOrderRepository orders;
  final cart = FakeCartRepository();
  final session = InMemorySessionRepository();

  Future<void> pump(WidgetTester tester, String orderId, {Size size = TestScreens.narrow, bool settle = true}) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: AppRoutes.orderCancelledOf(orderId),
      routes: [
        GoRoute(
          path: AppRoutes.orderCancelled,
          builder: (context, state) => ChangeNotifierProvider(
            create: (_) => OrderCancelledViewModel(
              orders: orders,
              cart: cart,
              session: session,
              analytics: FakeAnalyticsService(),
              crash: FakeCrashService(),
              uid: 'u1',
              orderId: state.pathParameters['id']!,
            ),
            child: const OrderCancelledScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.order,
          builder: (context, state) => Scaffold(body: Text('S07 ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: AppRoutes.cart,
          builder: (context, state) => const Scaffold(body: Text('CART')),
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
}

Future<String> _rejectedOrder(FakeOrderRepository orders) async {
  final id = await placeTestOrder(orders, uid: 'u1');
  await orders.reject(orders.all.single, reason: 'Hết nguyên liệu');
  return id;
}

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S10 at ${size.width.round()} dp shows who cancelled, why, the refund and the order', (tester) async {
      final harness = _Harness();
      final id = await _rejectedOrder(harness.orders);
      await harness.pump(tester, id, size: size);

      expect(byId('s10.header'), findsOneWidget);
      expect(find.text('#$id'), findsOneWidget);
      expect(find.text('Đơn tại Kiosk'), findsOneWidget);
      expect(find.text('Đã huỷ'), findsOneWidget);
      expect(find.text('Kiosk đã từ chối đơn này.'), findsOneWidget);
      expect(find.text('Lý do: Hết nguyên liệu'), findsOneWidget);
      expect(find.text('Hoàn 39.000đ về Ví MoMo trong khoảng 30 giây.'), findsOneWidget);
      expect(find.text('Combo ×1'), findsOneWidget);
      expect(find.text('Tổng 39.000đ'), findsOneWidget);
      expect(byId('s10.reorder'), findsOneWidget);
      expect(byId('s10.home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S10 does not repeat the fixed note of an order the customer cancelled themselves', (tester) async {
    final harness = _Harness();
    final id = await placeTestOrder(harness.orders, uid: 'u1', method: PaymentMethod.cash);
    await harness.orders.cancelMyOrder(harness.orders.all.single, reason: 'Khách huỷ trên ứng dụng');
    await harness.pump(tester, id);

    expect(find.text('Bạn đã huỷ đơn này.'), findsOneWidget);
    expect(byId('s10.reason'), findsNothing);
    expect(find.textContaining('Khách huỷ trên ứng dụng'), findsNothing);
    expect(find.text('Bạn chưa trả tiền cho đơn này nên không có khoản nào cần hoàn.'), findsOneWidget);
  });

  testWidgets('S10 reorder puts the items back in the cart and the snackbar opens it', (tester) async {
    final harness = _Harness();
    final id = await _rejectedOrder(harness.orders);
    await harness.pump(tester, id);

    await tester.tap(byId('s10.reorder'));
    await tester.pumpAndSettle();
    expect(find.text('Đã thêm 1 món vào giỏ'), findsOneWidget);
    expect(harness.cart.current('u1').items.single.itemId, 'm1');
    expect(harness.session.selectedKioskId, 'q9-t2');

    await tester.tap(find.text('Xem giỏ'));
    await tester.pumpAndSettle();
    expect(find.text('CART'), findsOneWidget);
  });

  testWidgets('S10 close button and the home button both go home', (tester) async {
    final harness = _Harness();
    final id = await _rejectedOrder(harness.orders);
    await harness.pump(tester, id);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);

    final other = _Harness();
    final otherId = await _rejectedOrder(other.orders);
    await other.pump(tester, otherId);
    await tester.tap(byId('s10.home'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('S10 shows the loading state while the order has not arrived', (tester) async {
    await _Harness(orders: _NeverLoads()).pump(tester, 'A-204', settle: false);
    expect(find.text('Đang tải đơn hàng…'), findsOneWidget);
  });

  testWidgets('S10 shows an error with a retry when the order cannot be loaded', (tester) async {
    await _Harness(orders: _FailingOrders()).pump(tester, 'A-204');
    expect(byId('s10.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('S10 shows the empty state for an unknown order and goes home', (tester) async {
    await _Harness().pump(tester, 'nope');
    expect(byId('s10.empty'), findsOneWidget);
    expect(find.text('Không tìm thấy đơn này.'), findsOneWidget);
    await tester.tap(find.text('Về trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('S10 sends an order that is not cancelled on to order tracking', (tester) async {
    final harness = _Harness();
    final id = await placeTestOrder(harness.orders, uid: 'u1');
    await harness.pump(tester, id);

    expect(find.text('Đơn này chưa bị huỷ.'), findsOneWidget);
    await tester.tap(find.text('Xem đơn'));
    await tester.pumpAndSettle();
    expect(find.text('S07 $id'), findsOneWidget);
  });
}
