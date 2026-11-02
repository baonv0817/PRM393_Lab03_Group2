import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/order_manage/view_models/review_view_model.dart';
import 'package:breakbite/ui/order_manage/widgets/review_screen.dart';
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

const _combo = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000);
const _tea = CartItem(itemId: 'm2', name: 'Trà đào', priceVnd: 25000);

class _Harness {
  _Harness({FakeOrderRepository? orders}) : orders = orders ?? FakeOrderRepository();

  final FakeOrderRepository orders;
  final reviews = FakeReviewRepository();

  Future<String> deliveredOrder() async {
    final id = await placeTestOrder(orders, uid: 'u1', items: const [_combo, _tea]);
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
      initialLocation: AppRoutes.orderReviewOf(orderId),
      routes: [
        GoRoute(
          path: AppRoutes.orderReview,
          builder: (context, state) => ChangeNotifierProvider(
            create: (_) => ReviewViewModel(
              orders: orders,
              reviews: reviews,
              crash: FakeCrashService(),
              uid: 'u1',
              displayName: 'Nguyễn Minh Quân',
              orderId: state.pathParameters['id']!,
            ),
            child: const ReviewScreen(),
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
    find.descendant(of: byId('s23.submit'), matching: find.byType(FilledButton)),
  );
  return button.onPressed != null;
}

Future<void> _tap(WidgetTester tester, String id) async {
  await tester.tap(byId(id));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S23 at ${size.width.round()} dp shows each item with stars, tags and a comment without overflow', (
      tester,
    ) async {
      final harness = _Harness();
      final id = await harness.deliveredOrder();
      await harness.pump(tester, id, size: size);

      expect(find.text('Đơn #$id · Kiosk'), findsOneWidget);
      for (final item in ['m1', 'm2']) {
        expect(byId('s23.item.$item'), findsOneWidget);
        for (var stars = 1; stars <= 5; stars++) {
          expect(byId('s23.item.$item.star.$stars'), findsOneWidget);
        }
        for (final tag in ReviewViewModel.tags) {
          expect(byId('s23.item.$item.tag.$tag'), findsOneWidget);
        }
        expect(byId('s23.item.$item.comment'), findsOneWidget);
      }
      expect(find.text('Combo Tacos Bò Phô Mai'), findsOneWidget);
      expect(find.text('Ngon'), findsNWidgets(2));
      expect(find.text('Chạm vào sao để chấm điểm ít nhất một món.'), findsOneWidget);
      expect(find.text('Gửi đánh giá'), findsOneWidget);
      expect(_submitEnabled(tester), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S23 rates an item, picks tags and writes a comment, then sends it and goes back to the order', (
    tester,
  ) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.pump(tester, id);

    await _tap(tester, 's23.item.m1.star.4');
    expect(find.text('Tốt'), findsOneWidget);
    expect(find.text('Gửi đánh giá (1 món)'), findsOneWidget);
    expect(_submitEnabled(tester), isTrue);
    await _tap(tester, 's23.item.m1.tag.tasty');
    await _tap(tester, 's23.item.m1.tag.hot');
    await tester.enterText(find.byType(TextField).first, 'Vỏ giòn, nhân đầy');
    await tester.pumpAndSettle();

    await tester.tap(byId('s23.submit'));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi 1 đánh giá. Cảm ơn bạn!'), findsOneWidget);
    expect(find.text('S12 $id'), findsOneWidget);
    final saved = harness.reviews.all.single;
    expect((saved.itemId, saved.rating, saved.comment), ('m1', 4, 'Vỏ giòn, nhân đầy'));
    expect(saved.tags, ['tasty', 'hot']);
    expect(saved.authorName, 'Quân N.');
  });

  testWidgets('S23 shows a review already sent and only offers to send what has changed', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.reviews.save(
      order: harness.orders.all.single,
      item: _tea,
      rating: 5,
      comment: 'Rất ngon',
      tags: const ['tasty'],
      authorName: 'Nguyễn Minh Quân',
    );
    await harness.pump(tester, id);

    expect(byId('s23.item.m2.reviewed'), findsOneWidget);
    expect(byId('s23.item.m1.reviewed'), findsNothing);
    expect(find.text('Tuyệt vời'), findsOneWidget);
    expect(find.text('Rất ngon'), findsOneWidget);
    expect(find.text('Bạn chưa thay đổi gì so với đánh giá đã gửi.'), findsOneWidget);
    expect(_submitEnabled(tester), isFalse);

    await _tap(tester, 's23.item.m2.star.3');
    expect(find.text('Bình thường'), findsOneWidget);
    expect(_submitEnabled(tester), isTrue);
    await tester.tap(byId('s23.submit'));
    await tester.pumpAndSettle();
    expect(harness.reviews.all, hasLength(1));
    expect(harness.reviews.all.single.rating, 3);
  });

  testWidgets('S23 says when sending fails and keeps what was written', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    harness.reviews.failNextSave = const NetworkException();
    await harness.pump(tester, id);
    await _tap(tester, 's23.item.m1.star.2');
    await tester.enterText(find.byType(TextField).first, 'Nguội');
    await tester.pumpAndSettle();

    await tester.tap(byId('s23.submit'));
    await tester.pumpAndSettle();

    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Nguội'), findsOneWidget);
    expect(_submitEnabled(tester), isTrue);
    expect(harness.reviews.all, isEmpty);
  });

  testWidgets('S23 back returns to the order detail when it was opened without a history', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.pump(tester, id);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('S12 $id'), findsOneWidget);
  });

  testWidgets('S23 of an order not received yet explains why and goes to the orders list', (tester) async {
    final harness = _Harness();
    final id = await placeTestOrder(harness.orders, uid: 'u1');
    await harness.pump(tester, id);

    expect(byId('s23.empty'), findsOneWidget);
    expect(find.text(ReviewViewModel.notDeliveredMessage), findsOneWidget);
    await tester.tap(find.text('Xem đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.text('ORDERS'), findsOneWidget);
  });

  testWidgets('S23 shows the empty state for an unknown order', (tester) async {
    await _Harness().pump(tester, 'nope');
    expect(byId('s23.empty'), findsOneWidget);
    expect(find.text('Không tìm thấy đơn này.'), findsOneWidget);
  });

  testWidgets('S23 shows the loading state while the order has not arrived', (tester) async {
    await _Harness(orders: _NeverLoads()).pump(tester, 'A-204', settle: false);
    expect(find.text('Đang tải đơn hàng…'), findsOneWidget);
  });

  testWidgets('S23 shows an error with a retry when the order cannot be loaded', (tester) async {
    await _Harness(orders: _FailingOrders()).pump(tester, 'A-204');
    expect(byId('s23.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
