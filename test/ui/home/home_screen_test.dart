import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/home/view_models/home_view_model.dart';
import 'package:breakbite/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';
import '../../helpers/pump.dart';

class _FailingMenu extends FakeMenuRepository {
  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) => Stream.error(Exception('offline'));
}

typedef Harness = ({FakeCartRepository cart, FakeAnalyticsService analytics, InMemorySessionRepository session});

Future<Harness> pumpHome(
  WidgetTester tester, {
  FakeMenuRepository? menu,
  FakeRemoteConfigService? rc,
  FakeOrderRepository? orders,
  InMemorySessionRepository? session,
  bool settle = true,
  Size size = TestScreens.narrow,
}) async {
  final cart = FakeCartRepository();
  final analytics = FakeAnalyticsService();
  final sessionRepository = session ?? InMemorySessionRepository();
  await pumpScreen(
    tester,
    const HomeScreen(),
    settle: settle,
    size: size,
    providers: [
      ChangeNotifierProvider(
        create: (_) => HomeViewModel(
          menu: menu ?? FakeMenuRepository(),
          cart: cart,
          orders: orders ?? FakeOrderRepository(),
          session: sessionRepository,
          remoteConfig: rc ?? FakeRemoteConfigService(),
          analytics: analytics,
          crash: FakeCrashService(),
          uid: 'u1',
        ),
      ),
    ],
  );
  return (cart: cart, analytics: analytics, session: sessionRepository);
}

void main() {
  testWidgets('shows loading then the quick items, without sold-out items', (tester) async {
    await pumpHome(tester, settle: false);
    expect(find.text('Đang tải…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Đang tải…'), findsNothing);
    expect(find.text('Món nhanh · tối đa 5 phút'), findsOneWidget);
    expect(find.text('Combo Tacos Bò Phô Mai'), findsOneWidget);
    expect(find.text('Mì Trộn Gà Cay Hàn Quốc'), findsOneWidget);
    expect(find.text('Trà Đào Chanh Sả'), findsOneWidget);
    expect(find.text('Tacos Gà Giòn Sốt Cay'), findsNothing);
  });

  testWidgets('every quick item shows its real photo (not the placeholder logo)', (tester) async {
    await pumpHome(tester);
    expect(find.byType(MenuItemImage), findsNWidgets(3));
    expect(find.byType(Image), findsNWidgets(3));
    expect(find.byType(BreakBiteLogo), findsNothing);
  });

  testWidgets('the header shows the kiosk, its wait time, notifications and the cart', (tester) async {
    await pumpHome(tester);
    expect(find.text('Kiosk Q9 · Tầng 2'), findsOneWidget);
    expect(find.text('Sẵn sàng · chờ 5–7 phút'), findsOneWidget);
    expect(find.byTooltip('Thông báo'), findsOneWidget);
    expect(find.byTooltip('Giỏ hàng, trống'), findsOneWidget);
  });

  testWidgets('shows the kiosk chosen in the session and switches when it changes (S27)', (tester) async {
    final h = await pumpHome(tester, session: InMemorySessionRepository(selectedKioskId: 'q9-t4'));
    expect(find.text('Kiosk Q9 · Tầng 4'), findsOneWidget);
    expect(find.text('Bánh Mì Chả Lụa Trứng'), findsOneWidget);

    await h.session.selectKiosk('q9-t2');
    await tester.pumpAndSettle();
    expect(find.text('Kiosk Q9 · Tầng 2'), findsOneWidget);
    expect(find.text('Combo Tacos Bò Phô Mai'), findsOneWidget);
  });

  testWidgets('key elements carry stable test ids for ARTEMIS', (tester) async {
    await pumpHome(tester);
    for (final id in ['s02.search', 's02.promo', 's02.notifications', 's02.cart', 's02.item.m1', 's02.item.m1.add']) {
      expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
    }
  });

  testWidgets('has a search field; no category chips and no extra banner button (D06)', (tester) async {
    await pumpHome(tester);
    expect(find.text('Tìm Tacos, Mì trộn, Đồ uống...'), findsOneWidget);
    expect(find.byType(AppChip), findsNothing);
    expect(find.text('Đặt ngay'), findsNothing);
  });

  testWidgets('the Golden Hour Combo banner follows Remote Config', (tester) async {
    await pumpHome(tester);
    expect(find.text('Combo Giờ Vàng –15%'), findsOneWidget);
  });

  testWidgets('turning the banner off in Remote Config hides it', (tester) async {
    await pumpHome(tester, rc: FakeRemoteConfigService()..values['promo_banner_enabled'] = false);
    expect(find.text('Combo Giờ Vàng –15%'), findsNothing);
  });

  testWidgets('a limit of 0 shows the empty state', (tester) async {
    await pumpHome(tester, rc: FakeRemoteConfigService()..values['quick_items_limit'] = 0);
    expect(find.text('Chưa có món nhanh lúc này'), findsOneWidget);
  });

  testWidgets('a network error shows a message and a Retry button', (tester) async {
    await pumpHome(tester, menu: _FailingMenu());
    expect(find.text('Không tải được thực đơn. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('tapping + writes the cart, logs the event and shows the "Đã thêm" snackbar', (tester) async {
    final h = await pumpHome(tester);
    await tester.tap(find.bySemanticsIdentifier('s02.item.m1.add'));
    await tester.pumpAndSettle();

    expect(find.text('Đã thêm Combo Tacos Bò Phô Mai vào giỏ'), findsOneWidget);
    expect(find.text('Xem giỏ'), findsOneWidget);
    expect(find.byTooltip('Giỏ hàng, 1 món'), findsOneWidget);
    final items = (await h.cart.watchCart('u1').first).items;
    expect(items.single.itemId, 'm1');
    expect(h.analytics.events.single.name, 'add_to_cart');
  });

  testWidgets('the + button has a touch target of at least 48 dp', (tester) async {
    await pumpHome(tester);
    final size = tester.getSize(find.byTooltip('Thêm Combo Tacos Bò Phô Mai vào giỏ'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('lays out without overflow at 412 dp too', (tester) async {
    await pumpHome(tester, size: TestScreens.wide);
    expect(tester.takeException(), isNull);
  });

  group('Reorder the latest order', () {
    testWidgets('hides the Reorder card when there is no order', (tester) async {
      await pumpHome(tester);
      expect(find.text('Đặt lại đơn gần đây'), findsNothing);
    });

    testWidgets('with an order it shows a summary; tapping adds the items to the cart', (tester) async {
      final orders = FakeOrderRepository();
      await placeTestOrder(
        orders,
        uid: 'u1',
        items: const [
          CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000),
          CartItem(itemId: 'm3', name: 'Trà Đào Chanh Sả', priceVnd: 20000),
        ],
        method: PaymentMethod.momo,
        kioskId: 'q9-t2',
      );
      final h = await pumpHome(tester, orders: orders);

      await tester.scrollUntilVisible(
        find.bySemanticsIdentifier('s02.reorder'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Combo Tacos Bò Phô Mai + 1 món · 59.000đ'), findsOneWidget);

      await tester.tap(find.text('Đặt lại đơn gần đây'));
      await tester.pumpAndSettle();
      expect(find.text('Đã thêm 2 món của đơn gần đây vào giỏ'), findsOneWidget);
      expect((await h.cart.watchCart('u1').first).items.map((e) => e.itemId), ['m1', 'm3']);
      expect(h.analytics.events.map((e) => e.name), contains('reorder'));
    });
  });
}
