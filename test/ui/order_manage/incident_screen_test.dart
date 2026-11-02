import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/order_manage/view_models/incident_view_model.dart';
import 'package:breakbite/ui/order_manage/widgets/incident_screen.dart';
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
  final incidents = FakeIncidentRepository();

  Future<String> deliveredOrder() async {
    final id = await placeTestOrder(orders, uid: 'u1');
    await orders.accept(orders.all.single, readyIn: const Duration(minutes: 5));
    await orders.markReady(orders.all.single);
    await orders.deliver(orders.all.single);
    return id;
  }

  Future<void> pump(WidgetTester tester, String orderId, {Size size = TestScreens.narrow, bool settle = true}) async {
    // The width is the phone's; the height is tall because a ListView only builds what is on screen and
    // the test font is wider than Nunito, so the whole page would otherwise need scrolling.
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = Size(size.width, 3200);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: AppRoutes.orderIncidentOf(orderId),
      routes: [
        GoRoute(
          path: AppRoutes.orderIncident,
          builder: (context, state) => ChangeNotifierProvider(
            create: (_) => IncidentViewModel(
              orders: orders,
              incidents: incidents,
              crash: FakeCrashService(),
              uid: 'u1',
              customerName: 'Nguyễn Minh Quân',
              orderId: state.pathParameters['id']!,
            ),
            child: const IncidentScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.orderDetail,
          builder: (context, state) => Scaffold(body: Text('S12 ${state.pathParameters['id']}')),
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
}

bool _submitEnabled(WidgetTester tester) {
  final button = tester.widget<FilledButton>(
    find.descendant(of: byId('s24.submit'), matching: find.byType(FilledButton)),
  );
  return button.onPressed != null;
}

Future<void> _fill(WidgetTester tester, {required String type, required String description}) async {
  await tester.tap(byId('s24.type.$type'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), description);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S24 at ${size.width.round()} dp offers the kinds of problem and a description without overflow', (
      tester,
    ) async {
      final harness = _Harness();
      final id = await harness.deliveredOrder();
      await harness.pump(tester, id, size: size);

      expect(byId('s24.header'), findsOneWidget);
      expect(find.text('Đơn #$id · Kiosk'), findsOneWidget);
      for (final type in IncidentViewModel.types) {
        expect(byId('s24.type.${type.name}'), findsOneWidget);
      }
      expect(find.text('Thiếu món'), findsOneWidget);
      expect(find.text('Sai món'), findsOneWidget);
      expect(find.text('Mô tả sự cố'), findsOneWidget);
      expect(find.text('Chọn loại sự cố.'), findsOneWidget);
      expect(_submitEnabled(tester), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S24 sends the report once a kind and a description are given, then shows it with its status', (
    tester,
  ) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.pump(tester, id);

    await tester.tap(byId('s24.type.missingItem'));
    await tester.pumpAndSettle();
    expect(find.text('Mô tả điều đã xảy ra để kiosk kiểm tra.'), findsOneWidget);
    expect(_submitEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), 'Thiếu 1 ly trà đào');
    await tester.pumpAndSettle();
    expect(byId('s24.hint'), findsNothing);
    expect(_submitEnabled(tester), isTrue);

    await tester.tap(byId('s24.submit'));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi báo cáo. Kiosk sẽ xem sớm.'), findsOneWidget);
    expect(byId('s24.report'), findsOneWidget);
    expect(find.text('Thiếu món'), findsOneWidget);
    expect(find.text('Thiếu 1 ly trà đào'), findsOneWidget);
    expect(find.text('Đã gửi, chờ kiosk xem'), findsOneWidget);
    expect(byId('s24.submit'), findsNothing);
    final stored = harness.incidents.all.single;
    expect((stored.orderId, stored.type, stored.customerName), (id, IncidentType.missingItem, 'Nguyễn Minh Quân'));
  });

  testWidgets('S24 says when sending fails and keeps what was typed', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    harness.incidents.failNextReport = const NetworkException();
    await harness.pump(tester, id);
    await _fill(tester, type: 'quality', description: 'Món nguội');

    await tester.tap(byId('s24.submit'));
    await tester.pumpAndSettle();

    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(byId('s24.submit'), findsOneWidget);
    expect(find.text('Món nguội'), findsOneWidget);
    expect(_submitEnabled(tester), isTrue);
    expect(harness.incidents.all, isEmpty);
  });

  testWidgets('S24 shows the kiosk answer when the report was refunded or rejected', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.incidents.report(
      order: harness.orders.all.single,
      type: IncidentType.wrongItem,
      description: 'Sai món',
    );
    await harness.pump(tester, id);
    expect(byId('s24.resolution'), findsNothing);
    expect(find.textContaining('Kiosk sẽ trả lời ngay tại đây'), findsOneWidget);

    harness.incidents.handle(
      id,
      status: IncidentStatus.resolved,
      resolution: IncidentResolution.refunded,
      refundVnd: 20000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Đã xử lý'), findsOneWidget);
    expect(find.text('Kiosk đồng ý hoàn 20.000đ cho bạn.'), findsOneWidget);

    harness.incidents.handle(
      id,
      status: IncidentStatus.resolved,
      resolution: IncidentResolution.rejected,
      resolutionNote: 'Đã kiểm camera, đủ món',
    );
    await tester.pumpAndSettle();
    expect(find.text('Kiosk không nhận báo cáo này: Đã kiểm camera, đủ món'), findsOneWidget);
  });

  testWidgets('S24 back returns to the order detail when it was opened without a history', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.pump(tester, id);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('S12 $id'), findsOneWidget);
  });

  testWidgets('S24 of a sent report offers a way back to the order', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.incidents.report(order: harness.orders.all.single, type: IncidentType.late, description: 'Lâu quá');
    await harness.pump(tester, id);

    await tester.tap(byId('s24.back'));
    await tester.pumpAndSettle();
    expect(find.text('S12 $id'), findsOneWidget);
  });

  testWidgets('S24 of an order not received yet explains why and goes to the orders list', (tester) async {
    final harness = _Harness();
    final id = await placeTestOrder(harness.orders, uid: 'u1');
    await harness.pump(tester, id);

    expect(byId('s24.empty'), findsOneWidget);
    expect(find.text(IncidentViewModel.notDeliveredMessage), findsOneWidget);
    await tester.tap(find.text('Xem đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.text('ORDERS'), findsOneWidget);
  });

  testWidgets('S24 shows the empty state for an unknown order', (tester) async {
    await _Harness().pump(tester, 'nope');
    expect(byId('s24.empty'), findsOneWidget);
    expect(find.text('Không tìm thấy đơn này.'), findsOneWidget);
  });

  testWidgets('S24 shows the loading state while the order has not arrived', (tester) async {
    await _Harness(orders: _NeverLoads()).pump(tester, 'A-204', settle: false);
    expect(find.text('Đang tải đơn hàng…'), findsOneWidget);
  });

  testWidgets('S24 shows an error with a retry when the order cannot be loaded', (tester) async {
    await _Harness(orders: _FailingOrders()).pump(tester, 'A-204');
    expect(byId('s24.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
