import 'package:breakbite/ui/cart/view_models/pickup_time_view_model.dart';
import 'package:breakbite/ui/cart/view_models/voucher_picker_view_model.dart';
import 'package:breakbite/ui/cart/widgets/pickup_time_screen.dart';
import 'package:breakbite/ui/cart/widgets/voucher_picker_screen.dart';
import 'package:breakbite/ui/orders/view_models/orders_view_model.dart';
import 'package:breakbite/ui/orders/widgets/orders_screen.dart';
import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Future<FakeCartRepository> _cartWithTacos(int quantity) async {
  final cart = FakeCartRepository();
  await cart.addItem(
    'u1',
    kioskId: 'q9-t2',
    item: CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000, quantity: quantity),
  );
  return cart;
}

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S29 at ${size.width.round()} dp lists the vouchers with what each needs', (tester) async {
      final cart = await _cartWithTacos(1);
      await pumpScreen(
        tester,
        const VoucherPickerScreen(),
        size: size,
        providers: [
          ChangeNotifierProvider(
            create: (_) => VoucherPickerViewModel(
              vouchers: FakeVoucherRepository(),
              menu: FakeMenuRepository(),
              cart: cart,
              crash: FakeCrashService(),
              uid: 'u1',
              clock: () => DateTime.utc(2026, 11, 2, 3),
            ),
          ),
        ],
      );
      expect(find.text('Nhập mã'), findsOneWidget);
      expect(find.text('Mã của bạn'), findsOneWidget);
      for (final code in ['BBSTUDENT', 'GIOVANG', 'BB20']) {
        expect(byId('s29.voucher.$code'), findsOneWidget);
      }
      expect(find.text('Giảm 10.000đ cho đơn từ 40.000đ'), findsOneWidget);
      expect(find.text('Mua thêm 1.000đ để dùng mã'), findsOneWidget);
      expect(find.text('Đã hết hạn'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'bb20');
      await tester.tap(byId('s29.apply'));
      await tester.pumpAndSettle();
      expect(find.text('Mã BB20 đã hết hạn.'), findsOneWidget);
      expect(cart.current('u1').voucherCode, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('S25 at ${size.width.round()} dp offers as soon as possible and the break slots', (tester) async {
      final cart = await _cartWithTacos(1);
      final now = DateTime(2026, 11, 2, 10);
      await pumpScreen(
        tester,
        const PickupTimeScreen(),
        size: size,
        providers: [
          ChangeNotifierProvider(
            create: (_) => PickupTimeViewModel(
              slots: FakeSlotRepository(clock: () => now),
              cart: cart,
              menu: FakeMenuRepository(),
              remoteConfig: FakeRemoteConfigService(),
              crash: FakeCrashService(),
              uid: 'u1',
              clock: () => now,
            ),
          ),
        ],
      );
      expect(find.text('Nhận tại Kiosk Q9 · Tầng 2'), findsOneWidget);
      expect(byId('s25.asap'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Đã đủ'), findsOneWidget);

      await tester.tap(byId('s25.slot.20261102-1315'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(byId('s25.summary'), 100, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Món sẵn sàng khoảng'), findsOneWidget);

      await tester.ensureVisible(byId('s25.slot.20261102-1445'));
      await tester.pumpAndSettle();
      await tester.tap(byId('s25.slot.20261102-1445'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nhận lúc 14:45–15:00'), findsOneWidget);
      expect(byId('s25.confirm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S08 with no order shows the empty state with a way to the menu', (tester) async {
    await pumpScreen(
      tester,
      const OrdersScreen(),
      providers: [
        ChangeNotifierProvider(
          create: (_) => OrdersViewModel(
            orders: FakeOrderRepository(),
            cart: FakeCartRepository(),
            session: InMemorySessionRepository(),
            analytics: FakeAnalyticsService(),
            crash: FakeCrashService(),
            uid: 'u1',
          ),
        ),
      ],
    );
    expect(find.text('Đang xử lý (0)'), findsOneWidget);
    expect(byId('s08.empty'), findsOneWidget);
    expect(find.text('Xem thực đơn'), findsOneWidget);
  });

  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S08 at ${size.width.round()} dp shows the order in progress, recent orders and the history', (
      tester,
    ) async {
      final orders = FakeOrderRepository();
      final doneId = await placeTestOrder(orders, uid: 'u1');
      final activeId = await placeTestOrder(orders, uid: 'u1');
      final done = orders.all.firstWhere((o) => o.id == doneId);
      await orders.accept(done, readyIn: const Duration(minutes: 3));
      await orders.markReady(orders.all.firstWhere((o) => o.id == doneId));
      await orders.deliver(orders.all.firstWhere((o) => o.id == doneId));
      await pumpScreen(
        tester,
        const OrdersScreen(),
        size: size,
        providers: [
          ChangeNotifierProvider(
            create: (_) => OrdersViewModel(
              orders: orders,
              cart: FakeCartRepository(),
              session: InMemorySessionRepository(),
              analytics: FakeAnalyticsService(),
              crash: FakeCrashService(),
              uid: 'u1',
            ),
          ),
        ],
      );
      expect(find.text('Đang xử lý (1)'), findsOneWidget);
      expect(byId('s08.order.$activeId'), findsOneWidget);
      expect(find.text('Xem mã QR nhận món'), findsOneWidget);
      expect(find.text('Chờ kiosk nhận đơn'), findsOneWidget);
      expect(find.text('Đơn gần đây'), findsOneWidget);
      expect(byId('s08.order.$doneId.reorder'), findsOneWidget);

      await tester.tap(byId('s08.tab.history'));
      await tester.pumpAndSettle();
      expect(byId('s08.order.$doneId'), findsOneWidget);
      expect(byId('s08.allHistory'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S08 at 200 % text: the tabs scroll instead of cutting "Đang xử lý (1)", and the words agree', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final orders = FakeOrderRepository();
    await placeTestOrder(orders, uid: 'u1');
    await pumpScreen(
      tester,
      const OrdersScreen(),
      providers: [
        ChangeNotifierProvider(
          create: (_) => OrdersViewModel(
            orders: orders,
            cart: FakeCartRepository(),
            session: InMemorySessionRepository(),
            analytics: FakeAnalyticsService(),
            crash: FakeCrashService(),
            uid: 'u1',
          ),
        ),
      ],
    );
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
    expect(find.text('Đang xử lý (1)'), findsOneWidget);
    // A placed order waits for the kiosk: the badge no longer says "Đã nhận đơn" above "Chờ kiosk nhận đơn".
    expect(find.text('Chờ xác nhận'), findsOneWidget);
    expect(find.text('Chờ kiosk nhận đơn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
