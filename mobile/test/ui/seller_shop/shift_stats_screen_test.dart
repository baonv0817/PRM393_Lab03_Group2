import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/seller_shop/view_models/shift_stats_view_model.dart';
import 'package:breakbite/ui/seller_shop/widgets/shift_stats_screen.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

/// Reads fail while [offline] is set.
class _Orders extends FakeOrderRepository {
  bool offline = false;
  int reads = 0;

  @override
  Future<Result<KioskStats>> kioskStats(String kioskId, {required DateTime since}) {
    reads++;
    if (offline) return Future.value(const Result.error(NetworkException()));
    return super.kioskStats(kioskId, since: since);
  }
}

Future<void> _deliver(FakeOrderRepository orders, String id) async {
  Order current() => orders.all.firstWhere((o) => o.id == id);
  await orders.accept(current(), readyIn: const Duration(minutes: 5));
  await orders.markReady(current());
  await orders.deliver(current());
}

/// Two delivered orders (74.000đ), one cancelled, one still pending, all placed at 9:0x.
Future<_Orders> _shift() async {
  final orders = _Orders();
  final a = await placeTestOrder(orders, uid: 'u1');
  final b = await placeTestOrder(
    orders,
    uid: 'u2',
    items: const [CartItem(itemId: 'm2', name: 'Mì', priceVnd: 35000)],
  );
  final c = await placeTestOrder(orders, uid: 'u3');
  await placeTestOrder(orders, uid: 'u4');
  await _deliver(orders, a);
  await _deliver(orders, b);
  await orders.reject(orders.all.firstWhere((o) => o.id == c), reason: 'Hết món');
  return orders;
}

Future<void> _pump(
  WidgetTester tester,
  _Orders orders, {
  String? kioskId = 'q9-t2',
  Size size = TestScreens.narrow,
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(size.width, 2400);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: AppRoutes.sellerStats,
    routes: [
      GoRoute(
        path: AppRoutes.sellerShop,
        builder: (context, state) => const Scaffold(body: Text('K10')),
      ),
      GoRoute(
        path: AppRoutes.sellerStats,
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => ShiftStatsViewModel(
            orders: orders,
            menu: FakeMenuRepository(),
            crash: FakeCrashService(),
            kioskId: kioskId,
            clock: () => DateTime(2026, 11, 2, 12),
          ),
          child: const ShiftStatsScreen(),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(theme: AppTheme.light(), routerConfig: router));
  if (settle) await tester.pumpAndSettle();
}

String _textOf(WidgetTester tester, String id) =>
    tester.widgetList<Text>(find.descendant(of: byId(id), matching: find.byType(Text))).map((t) => t.data).join('|');

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide, Size(1024, 768)]) {
    testWidgets('K11 at ${size.width.round()} dp shows the revenue, the counts and the chart', (tester) async {
      await _pump(tester, await _shift(), size: size);

      expect(find.text('Ca hôm nay'), findsOneWidget);
      expect(_textOf(tester, 'k11.shift'), contains('Kiosk Q9 · Tầng 2'));
      expect(_textOf(tester, 'k11.shift'), contains('Từ 00:00 hôm nay'));
      expect(_textOf(tester, 'k11.shift'), contains('Cập nhật lúc 12:00'));
      expect(_textOf(tester, 'k11.revenue'), 'Doanh thu|74.000đ');
      expect(_textOf(tester, 'k11.delivered'), 'Đơn đã làm|2');
      expect(find.text('Đang xử lý: 1 đơn'), findsOneWidget);
      expect(_textOf(tester, 'k11.cancelled'), 'Đơn huỷ|1');
      expect(_textOf(tester, 'k11.prep'), 'Làm trung bình|1 phút');
      expect(find.text('Cao điểm 09:00 · 3 đơn'), findsOneWidget);
      expect(byId('k11.bar.9'), findsOneWidget);
      expect(byId('k11.bar.12'), findsOneWidget, reason: 'the chart runs up to the current hour');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('K11 the chart lists each hour with its count for a screen reader', (tester) async {
    await _pump(tester, await _shift());

    expect(find.bySemanticsLabel('9 giờ: 3 đơn'), findsOneWidget);
    expect(find.bySemanticsLabel('10 giờ: 0 đơn'), findsOneWidget);
    expect(find.bySemanticsLabel('Đơn huỷ: 1'), findsOneWidget);
  });

  testWidgets('K11 says when the shift has no order, and refreshing picks up a new one', (tester) async {
    final orders = _Orders();
    await _pump(tester, orders);

    expect(byId('k11.empty'), findsOneWidget);
    expect(find.text(ShiftStatsViewModel.emptyMessage), findsOneWidget);

    await placeTestOrder(orders, uid: 'u1');
    await tester.tap(byId('k11.refresh'));
    await tester.pumpAndSettle();

    expect(byId('k11.empty'), findsNothing);
    expect(find.text('Đang xử lý: 1 đơn'), findsOneWidget);
    expect(find.text('0đ'), findsOneWidget);
  });

  testWidgets('K11 the refresh button reads the figures again', (tester) async {
    final orders = await _shift();
    await _pump(tester, orders);
    expect(orders.reads, 1);

    await tester.tap(byId('k11.refresh'));
    await tester.pumpAndSettle();

    expect(orders.reads, 2);
  });

  testWidgets('K11 keeps the figures and says so when a refresh fails', (tester) async {
    final orders = await _shift();
    await _pump(tester, orders);

    orders.offline = true;
    await tester.tap(byId('k11.refresh'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa cập nhật được: ${const NetworkException().message}'), findsOneWidget);
    expect(_textOf(tester, 'k11.delivered'), 'Đơn đã làm|2');
  });

  testWidgets('K11 shows an error with retry when the first read fails, and a message without a kiosk', (tester) async {
    final orders = await _shift();
    orders.offline = true;
    await _pump(tester, orders);

    expect(byId('k11.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);

    orders.offline = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(byId('k11.revenue'), findsOneWidget);

    await _pump(tester, orders, kioskId: null);
    expect(find.text(ShiftStatsViewModel.noKioskMessage), findsOneWidget);
    expect(byId('k11.refresh'), findsNothing);
  });

  testWidgets('K11 the back button returns to the shop', (tester) async {
    await _pump(tester, await _shift());

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    expect(find.text('K10'), findsOneWidget);
  });

  testWidgets('K11 notes that the chart counts the newest orders only when it was cut', (tester) async {
    final orders = _TruncatedOrders();
    await placeTestOrder(orders, uid: 'u1');
    await _pump(tester, orders);

    expect(find.text(ShiftStatsViewModel.truncatedNote), findsOneWidget);
  });
}

class _TruncatedOrders extends _Orders {
  @override
  Future<Result<KioskStats>> kioskStats(String kioskId, {required DateTime since}) async {
    final stats = (await super.kioskStats(kioskId, since: since) as Ok<KioskStats>).value;
    return Result.ok(
      KioskStats(
        deliveredCount: stats.deliveredCount,
        revenueVnd: stats.revenueVnd,
        cancelledCount: stats.cancelledCount,
        activeCount: stats.activeCount,
        ordersByHour: stats.ordersByHour,
        chartTruncated: true,
      ),
    );
  }
}
