import 'dart:async';

import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/order_manage/view_models/order_history_view_model.dart';
import 'package:breakbite/ui/order_manage/widgets/order_history_screen.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:breakbite_core/utils/paged.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/order_history.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

final _now = DateTime(2026, 11, 4, 10);

/// This week: one delivered and one cancelled order; last week: one; a month before that: one.
List<Order> _orders() => [
  historyOrder('o1', DateTime(2026, 11, 3, 12), deliveredAt: DateTime(2026, 11, 3, 12, 30)),
  historyOrder('o2', DateTime(2026, 11, 2, 8), status: OrderStatus.cancelled, total: 20000),
  historyOrder('o3', DateTime(2026, 10, 29, 12), total: 50000),
  historyOrder('o4', DateTime(2026, 9, 15, 12), total: 60000),
];

Future<void> _pump(
  WidgetTester tester,
  PagedOrders repo, {
  int pageSize = 20,
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
    initialLocation: AppRoutes.ordersHistory,
    routes: [
      GoRoute(
        path: AppRoutes.ordersHistory,
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => OrderHistoryViewModel(
            orders: repo,
            crash: FakeCrashService(),
            uid: 'u1',
            pageSize: pageSize,
            clock: () => _now,
          ),
          child: const OrderHistoryScreen(),
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
      GoRoute(
        path: AppRoutes.menu,
        builder: (context, state) => const Scaffold(body: Text('MENU')),
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

class _NeverLoads extends PagedOrders {
  _NeverLoads() : super(const []);

  @override
  Future<Result<Paged<Order>>> fetchMyOrders(String uid, {int limit = Paged.defaultLimit, PageCursor? after}) =>
      Completer<Result<Paged<Order>>>().future;
}

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S11 at ${size.width.round()} dp groups the orders by week without overflow', (tester) async {
      await _pump(tester, PagedOrders(_orders()), size: size);

      expect(byId('s11.grouping.week'), findsOneWidget);
      expect(byId('s11.group.w20261102'), findsOneWidget);
      expect(find.text('Tuần này (02/11 – 08/11)'), findsOneWidget);
      expect(find.text('2 đơn (1 đã huỷ) · đã chi 39.000đ'), findsOneWidget);
      expect(find.text('Tuần trước (26/10 – 01/11)'), findsOneWidget);
      expect(find.text('Tuần 14/09 – 20/09'), findsOneWidget);
      expect(byId('s11.order.o1'), findsOneWidget);
      expect(find.text('#O1 · 03/11'), findsOneWidget);
      expect(find.text('Đã lấy món lúc 12:30'), findsOneWidget);
      expect(find.text('Đã huỷ'), findsOneWidget);
      expect(find.text('Đã hiển thị tất cả đơn của bạn.'), findsOneWidget);
      expect(byId('s11.more'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S11 shows what was spent this week, with the busiest day in the bars, and this month on the other tab', (
    tester,
  ) async {
    await _pump(tester, PagedOrders(_orders()));

    expect(find.text('Chi tiêu tuần này'), findsOneWidget);
    expect(find.descendant(of: byId('s11.spend'), matching: find.text('39.000đ')), findsOneWidget);
    for (var day = 0; day < 7; day++) {
      expect(byId('s11.spend.bar.$day'), findsOneWidget);
    }
    expect(find.bySemanticsLabel('T3: 39.000đ'), findsOneWidget, reason: 'o1 was placed on Tuesday 3 November');
    expect(find.bySemanticsLabel('T2: 0đ'), findsOneWidget);

    await tester.tap(byId('s11.grouping.month'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiêu tháng 11'), findsOneWidget);
    expect(find.descendant(of: byId('s11.spend'), matching: find.text('39.000đ')), findsOneWidget);
  });

  testWidgets('S11 switches to months and back', (tester) async {
    await _pump(tester, PagedOrders(_orders()));

    await tester.tap(byId('s11.grouping.month'));
    await tester.pumpAndSettle();
    expect(find.text('Tháng này (11/2026)'), findsOneWidget);
    expect(find.text('Tháng trước (10/2026)'), findsOneWidget);
    expect(find.text('Tháng 9/2026'), findsOneWidget);
    expect(find.textContaining('Tuần '), findsNothing);

    await tester.tap(byId('s11.grouping.week'));
    await tester.pumpAndSettle();
    expect(find.text('Tuần này (02/11 – 08/11)'), findsOneWidget);
    expect(find.textContaining('Tháng '), findsNothing);
  });

  testWidgets('S11 opens an order in its detail', (tester) async {
    await _pump(tester, PagedOrders(_orders()));

    await tester.tap(byId('s11.order.o3'));
    await tester.pumpAndSettle();
    expect(find.text('S12 o3'), findsOneWidget);
  });

  testWidgets('S11 loads older orders on request and the button goes away at the end', (tester) async {
    await _pump(tester, PagedOrders(_orders()), pageSize: 1);

    expect(byId('s11.order.o1'), findsOneWidget);
    expect(byId('s11.order.o2'), findsNothing);
    expect(find.text('Đã hiển thị tất cả đơn của bạn.'), findsNothing);

    await tester.tap(byId('s11.more'));
    await tester.pumpAndSettle();
    expect(byId('s11.order.o2'), findsOneWidget);
    expect(byId('s11.order.o3'), findsNothing);

    await tester.tap(byId('s11.more'));
    await tester.pumpAndSettle();
    expect(byId('s11.order.o3'), findsOneWidget);
    expect(byId('s11.order.o4'), findsNothing);
    expect(byId('s11.more'), findsOneWidget);

    await tester.tap(byId('s11.more'));
    await tester.pumpAndSettle();
    expect(byId('s11.order.o4'), findsOneWidget);
    expect(byId('s11.more'), findsNothing);
    expect(find.text('Đã hiển thị tất cả đơn của bạn.'), findsOneWidget);
  });

  testWidgets('S11 keeps the list and says so when older orders cannot be loaded', (tester) async {
    final repo = PagedOrders(_orders());
    await _pump(tester, repo, pageSize: 2);

    repo.failNext = const NetworkException();
    await tester.tap(byId('s11.more'));
    await tester.pumpAndSettle();
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(byId('s11.order.o1'), findsOneWidget);
    expect(byId('s11.more'), findsOneWidget);
  });

  testWidgets('S11 shows the loading state while the first page has not arrived', (tester) async {
    await _pump(tester, _NeverLoads(), settle: false);
    expect(find.text('Đang tải lịch sử đơn…'), findsOneWidget);
  });

  testWidgets('S11 shows an error with a retry, and retry loads the list', (tester) async {
    final repo = PagedOrders(_orders())..failNext = const NetworkException();
    await _pump(tester, repo);

    expect(byId('s11.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(byId('s11.order.o1'), findsOneWidget);
  });

  testWidgets('S11 shows the empty state with a way to the menu', (tester) async {
    await _pump(tester, PagedOrders(const <Order>[]));

    expect(byId('s11.empty'), findsOneWidget);
    expect(find.text(OrderHistoryViewModel.emptyMessage), findsOneWidget);
    await tester.tap(find.text('Xem thực đơn'));
    await tester.pumpAndSettle();
    expect(find.text('MENU'), findsOneWidget);
  });

  testWidgets('S11 back goes to the orders list when it was opened without a history', (tester) async {
    await _pump(tester, PagedOrders(_orders()));

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('ORDERS'), findsOneWidget);
  });
}
