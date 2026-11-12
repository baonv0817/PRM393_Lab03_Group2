import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/order_manage/view_models/edit_order_view_model.dart';
import 'package:breakbite/ui/order_manage/widgets/edit_order_screen.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
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

class _OfflineSave extends FakeOrderRepository {
  _OfflineSave() : super(vouchers: {for (final v in fakeVouchers) v.code: v});

  @override
  Future<Result<void>> editPendingOrder(
    Order order, {
    required List<CartItem> items,
    String? voucherCode,
    String? pickupSlotId,
    String note = '',
  }) async => const Result.error(NetworkException());
}

/// Fails the first save, then behaves like the normal repository.
class _FailsOnce extends FakeOrderRepository {
  _FailsOnce() : super(vouchers: {for (final v in fakeVouchers) v.code: v});

  var _failed = false;

  @override
  Future<Result<void>> editPendingOrder(
    Order order, {
    required List<CartItem> items,
    String? voucherCode,
    String? pickupSlotId,
    String note = '',
  }) {
    if (!_failed) {
      _failed = true;
      return Future.value(const Result.error(NetworkException()));
    }
    return super.editPendingOrder(
      order,
      items: items,
      voucherCode: voucherCode,
      pickupSlotId: pickupSlotId,
      note: note,
    );
  }
}

const _combo = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000, quantity: 2, note: 'Ít cay');
const _tea = CartItem(itemId: 'm2', name: 'Trà đào', priceVnd: 25000);

FakeOrderRepository _orders() => FakeOrderRepository(vouchers: {for (final v in fakeVouchers) v.code: v});

/// 2 combos with a note and a tea, BBSTUDENT: 103.000đ − 10.000đ = 93.000đ, still pending.
Future<String> _place(FakeOrderRepository orders, {List<CartItem> items = const [_combo, _tea]}) async {
  final result = await orders.placeOrder(
    OrderDraft(
      uid: 'u1',
      customerName: 'Khách',
      kioskId: 'q9-t2',
      kioskName: 'Kiosk Q9 · Tầng 2',
      items: items,
      paymentMethod: PaymentMethod.momo,
      voucherCode: 'BBSTUDENT',
    ),
  );
  return result.valueOrNull!;
}

Future<void> _pump(
  WidgetTester tester,
  OrderRepository orders,
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
    initialLocation: AppRoutes.orderEditOf(orderId),
    routes: [
      GoRoute(
        path: AppRoutes.orderEdit,
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => EditOrderViewModel(
            orders: orders,
            menu: FakeMenuRepository(),
            crash: FakeCrashService(),
            orderId: state.pathParameters['id']!,
            clock: () => DateTime(2026, 11, 2, 10),
          ),
          child: const EditOrderScreen(),
        ),
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

Future<void> _tap(WidgetTester tester, String id) async {
  await tester.tap(byId(id));
  await tester.pumpAndSettle();
}

bool _saveEnabled(WidgetTester tester) {
  final button = tester.widget<FilledButton>(
    find.descendant(of: byId('s09.save'), matching: find.byType(FilledButton)),
  );
  return button.onPressed != null;
}

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S09 at ${size.width.round()} dp shows the lines, the voucher and the bill without overflow', (
      tester,
    ) async {
      final orders = _orders();
      final id = await _place(orders);
      await _pump(tester, orders, id, size: size);

      expect(byId('s09.header'), findsOneWidget);
      expect(find.text('Đơn #$id · Kiosk Q9 · Tầng 2'), findsOneWidget);
      expect(byId('s09.item.m1'), findsOneWidget);
      expect(find.text('Ít cay'), findsOneWidget);
      expect(find.text('Trà đào'), findsOneWidget);
      expect(find.text('+ Thêm ghi chú cho bếp'), findsOneWidget);
      expect(find.text('BBSTUDENT · −10.000đ'), findsOneWidget);
      expect(find.text('Tạm tính (3 món)'), findsOneWidget);
      expect(find.text('93.000đ'), findsOneWidget);
      expect(find.text('Trước khi sửa'), findsNothing);
      expect(byId('s09.save'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S09 saving is off until something changes, and the bill follows the quantities', (tester) async {
    final orders = _orders();
    final id = await _place(orders);
    await _pump(tester, orders, id);
    expect(_saveEnabled(tester), isFalse);

    await _tap(tester, 's09.item.m1.inc');
    expect(find.text('132.000đ'), findsOneWidget);
    expect(find.text('Trước khi sửa'), findsOneWidget);
    expect(find.text('93.000đ'), findsOneWidget);
    expect(_saveEnabled(tester), isTrue);

    await _tap(tester, 's09.item.m1.dec');
    expect(find.text('Trước khi sửa'), findsNothing);
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('S09 removes a line and says an order cannot lose its last one', (tester) async {
    final orders = _orders();
    final id = await _place(orders, items: const [_combo, _tea]);
    await _pump(tester, orders, id);

    await _tap(tester, 's09.item.m2.dec');
    expect(byId('s09.item.m2'), findsNothing);
    expect(find.text('Tạm tính (2 món)'), findsOneWidget);
    expect(byId('s09.lastLine'), findsNothing);

    await _tap(tester, 's09.item.m1.dec');
    expect(byId('s09.lastLine'), findsOneWidget);
    expect(find.text(EditOrderViewModel.lastLineMessage), findsOneWidget);
    await tester.tap(byId('s09.item.m1.dec'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(byId('s09.item.m1'), findsOneWidget);
  });

  testWidgets('S09 shows why the voucher no longer fits, blocks saving, and lets it be dropped or taken back', (
    tester,
  ) async {
    final orders = _orders();
    final id = await _place(orders);
    await _pump(tester, orders, id);

    await _tap(tester, 's09.item.m2.dec');
    await _tap(tester, 's09.item.m1.dec');
    expect(find.text('Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT.'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);

    await _tap(tester, 's09.voucher.drop');
    expect(find.text('Đã bỏ mã BBSTUDENT'), findsOneWidget);
    expect(find.text('Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT.'), findsNothing);
    expect(_saveEnabled(tester), isTrue);

    await _tap(tester, 's09.voucher.keep');
    expect(find.text('Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT.'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('S09 edits the note of a line in a sheet', (tester) async {
    final orders = _orders();
    final id = await _place(orders);
    await _pump(tester, orders, id);

    await _tap(tester, 's09.item.m2.note');
    expect(find.text('Ghi chú cho Trà đào'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ít đá');
    await tester.pumpAndSettle();
    await _tap(tester, 's09.noteSave');

    expect(find.text('ít đá'), findsOneWidget);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('S09 saves, tells the customer and returns to the order, which shows the new total', (tester) async {
    final orders = _orders();
    final id = await _place(orders);
    await _pump(tester, orders, id);

    await _tap(tester, 's09.item.m1.inc');
    await _tap(tester, 's09.save');

    expect(find.text('Đã cập nhật đơn.'), findsOneWidget);
    expect(find.text('S07 $id'), findsOneWidget);
    final saved = orders.all.single;
    expect(saved.items.first.quantity, 3);
    expect(saved.totalVnd, 132000);
  });

  testWidgets('S09 says when saving fails and keeps the changes', (tester) async {
    final orders = _OfflineSave();
    final id = await _place(orders);
    await _pump(tester, orders, id);

    await _tap(tester, 's09.item.m1.inc');
    await _tap(tester, 's09.save');

    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('132.000đ'), findsOneWidget);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('S09 can save again at once after a failed save: the message does not cover the button', (tester) async {
    final orders = _FailsOnce();
    final id = await _place(orders);
    await _pump(tester, orders, id);
    await _tap(tester, 's09.item.m1.inc');

    await tester.tap(byId('s09.save'));
    await tester.pumpAndSettle();
    expect(find.text(const NetworkException().message), findsOneWidget);

    await tester.tap(byId('s09.save'));
    await tester.pumpAndSettle();
    expect(find.text('S07 $id'), findsOneWidget);
    expect(orders.all.single.items.first.quantity, 3);
  });

  testWidgets('S09 of an order the kitchen already took is locked, with a way to the order', (tester) async {
    final orders = _orders();
    final id = await _place(orders);
    await orders.accept(orders.all.single, readyIn: const Duration(minutes: 5));
    await _pump(tester, orders, id);

    expect(byId('s09.locked'), findsOneWidget);
    expect(find.text(EditOrderViewModel.lockedMessage), findsOneWidget);
    expect(byId('s09.save'), findsNothing);
    await tester.tap(find.text('Xem đơn'));
    await tester.pumpAndSettle();
    expect(find.text('S07 $id'), findsOneWidget);
  });

  testWidgets('S09 locks while open when the kitchen takes the order', (tester) async {
    final orders = _orders();
    final id = await _place(orders);
    await _pump(tester, orders, id);
    expect(byId('s09.save'), findsOneWidget);

    await orders.accept(orders.all.single, readyIn: const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(byId('s09.locked'), findsOneWidget);
    expect(byId('s09.save'), findsNothing);
  });

  testWidgets('S09 shows the loading state while the order has not arrived', (tester) async {
    await _pump(tester, _NeverLoads(), 'A-204', settle: false);
    expect(find.text('Đang tải đơn hàng…'), findsOneWidget);
  });

  testWidgets('S09 shows an error with a retry when the order cannot be loaded', (tester) async {
    await _pump(tester, _FailingOrders(), 'A-204');
    expect(byId('s09.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('S09 shows the empty state for an unknown order and goes to the orders list', (tester) async {
    await _pump(tester, FakeOrderRepository(), 'nope');
    expect(byId('s09.empty'), findsOneWidget);
    expect(find.text('Không tìm thấy đơn này.'), findsOneWidget);
    await tester.tap(find.text('Xem đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.text('ORDERS'), findsOneWidget);
  });

  testWidgets('S09 back goes to the order when it was opened without a history', (tester) async {
    final orders = _orders();
    final id = await _place(orders);
    await _pump(tester, orders, id);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('S07 $id'), findsOneWidget);
  });
}
