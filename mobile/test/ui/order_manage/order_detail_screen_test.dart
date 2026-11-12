import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/order_manage/view_models/order_detail_view_model.dart';
import 'package:breakbite/ui/order_manage/widgets/order_detail_screen.dart';
import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  _Harness({FakeOrderRepository? orders})
    : orders = orders ?? FakeOrderRepository(vouchers: {for (final v in fakeVouchers) v.code: v});

  final FakeOrderRepository orders;
  final cart = FakeCartRepository();
  final session = InMemorySessionRepository();
  final storage = FakeStorageService();
  final reportFiles = FakeReportFileService();
  final reports = FakeReportRepository();

  /// A delivered MoMo order: 2 combos with a note and a tea, BBSTUDENT voucher, 93.000đ.
  Future<String> deliveredOrder() async {
    final result = await orders.placeOrder(
      const OrderDraft(
        uid: 'u1',
        customerName: 'Khách',
        kioskId: 'q9-t2',
        kioskName: 'Kiosk Q9 · Tầng 2',
        items: [
          CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000, quantity: 2, note: 'Ít cay'),
          CartItem(itemId: 'm2', name: 'Trà đào', priceVnd: 25000),
        ],
        paymentMethod: PaymentMethod.momo,
        voucherCode: 'BBSTUDENT',
        note: 'Gói riêng',
      ),
    );
    final id = result.valueOrNull!;
    Order current() => orders.all.firstWhere((o) => o.id == id);
    await orders.accept(current(), readyIn: const Duration(minutes: 5));
    await orders.markReady(current());
    await orders.deliver(current());
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
      initialLocation: AppRoutes.orderDetailOf(orderId),
      routes: [
        GoRoute(
          path: AppRoutes.orderDetail,
          builder: (context, state) => ChangeNotifierProvider(
            create: (_) => OrderDetailViewModel(
              orders: orders,
              cart: cart,
              session: session,
              storage: storage,
              reportFiles: reportFiles,
              reports: reports,
              analytics: FakeAnalyticsService(),
              crash: FakeCrashService(),
              uid: 'u1',
              customerName: 'Nguyễn Minh Quân',
              orderId: state.pathParameters['id']!,
            ),
            child: const OrderDetailScreen(),
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
        GoRoute(
          path: AppRoutes.cart,
          builder: (context, state) => const Scaffold(body: Text('CART')),
        ),
        GoRoute(
          path: AppRoutes.orderIncident,
          builder: (context, state) => Scaffold(body: Text('S24 ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: AppRoutes.orderReview,
          builder: (context, state) => Scaffold(body: Text('S23 ${state.pathParameters['id']}')),
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

/// Records what the app puts on the clipboard.
List<String> _mockClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S12 at ${size.width.round()} dp shows the order in full without overflow', (tester) async {
      final harness = _Harness();
      final id = await harness.deliveredOrder();
      await harness.pump(tester, id, size: size);

      expect(byId('s12.header'), findsOneWidget);
      expect(find.text('#$id'), findsOneWidget);
      expect(find.text('Hoàn tất'), findsOneWidget);
      for (final step in ['Đặt đơn', 'Kiosk nhận đơn', 'Món sẵn sàng', 'Nhận món']) {
        expect(find.text(step), findsOneWidget);
      }
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        debugPrint('TXT: ${w.data}');
      }
      expect(find.text('Combo Tacos Bò Phô Mai ×2'), findsOneWidget);
      expect(find.text('Ghi chú: Ít cay'), findsOneWidget);
      expect(find.text('78.000đ'), findsOneWidget);
      expect(find.text('Trà đào ×1'), findsOneWidget);
      expect(find.text('103.000đ'), findsOneWidget);
      expect(find.text('Giảm giá (BBSTUDENT)'), findsOneWidget);
      expect(find.text('−10.000đ'), findsOneWidget);
      expect(find.text('93.000đ'), findsOneWidget);
      expect(find.text('Ví MoMo · Đã thanh toán'), findsOneWidget);
      expect(find.text('Nhận ngay khi sẵn sàng'), findsOneWidget);
      expect(find.text('Ghi chú cho bếp: Gói riêng'), findsOneWidget);
      expect(byId('s12.reorder'), findsOneWidget);
      expect(byId('s12.export'), findsOneWidget);
      expect(byId('s12.track'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S12 of an order still in progress offers to track it instead of reordering', (tester) async {
    final harness = _Harness();
    final id = await placeTestOrder(harness.orders, uid: 'u1');
    await harness.pump(tester, id);

    expect(byId('s12.reorder'), findsNothing);
    expect(byId('s12.incident'), findsNothing);
    await tester.tap(byId('s12.track'));
    await tester.pumpAndSettle();
    expect(find.text('S07 $id'), findsOneWidget);
  });

  testWidgets('S12 of a received order offers to rate the items, which opens S23', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.pump(tester, id);

    expect(byId('s12.review'), findsOneWidget);
    await tester.tap(byId('s12.review'));
    await tester.pumpAndSettle();
    expect(find.text('S23 $id'), findsOneWidget);
  });

  testWidgets('S12 of an order that is not received or was cancelled does not offer a review', (tester) async {
    final harness = _Harness();
    final pending = await placeTestOrder(harness.orders, uid: 'u1');
    await harness.pump(tester, pending);
    expect(byId('s12.review'), findsNothing);

    final other = _Harness();
    final cancelled = await placeTestOrder(other.orders, uid: 'u1');
    await other.orders.cancelMyOrder(other.orders.all.single);
    await other.pump(tester, cancelled);
    expect(byId('s12.review'), findsNothing);
  });

  testWidgets('S12 of a received order offers to report a problem, which opens S24', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.pump(tester, id);

    expect(byId('s12.incident'), findsOneWidget);
    await tester.tap(byId('s12.incident'));
    await tester.pumpAndSettle();
    expect(find.text('S24 $id'), findsOneWidget);
  });

  testWidgets('S12 of a cancelled order does not offer to report a problem', (tester) async {
    final harness = _Harness();
    final id = await placeTestOrder(harness.orders, uid: 'u1');
    await harness.orders.cancelMyOrder(harness.orders.all.single);
    await harness.pump(tester, id);

    expect(byId('s12.reorder'), findsOneWidget);
    expect(byId('s12.incident'), findsNothing);
  });

  testWidgets('S12 reorder puts the items back in the cart and the snackbar opens it', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.pump(tester, id);

    await tester.tap(byId('s12.reorder'));
    await tester.pumpAndSettle();
    expect(find.text('Đã thêm 2 món vào giỏ'), findsOneWidget);
    expect(harness.cart.current('u1').items, hasLength(2));

    await tester.tap(find.text('Xem giỏ'));
    await tester.pumpAndSettle();
    expect(find.text('CART'), findsOneWidget);
  });

  testWidgets('S12 exports the receipt: progress, then the uploaded file with its link, which can be copied', (
    tester,
  ) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    final copied = _mockClipboard(tester);
    await harness.pump(tester, id);

    await tester.tap(byId('s12.export'));
    await tester.pump();
    expect(byId('s12.export.progress'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 25));
    expect(find.textContaining('Đang tải lên'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(byId('s12.export.progress'), findsNothing);
    expect(find.text('Đã tải biên nhận lên.'), findsOneWidget);
    expect(byId('s12.export.card'), findsOneWidget);
    expect(find.textContaining('Đã tải lên · '), findsOneWidget);
    final report = harness.reports.all.single;
    expect(report.orderId, id);
    expect(find.text(report.fileName), findsOneWidget);
    expect(find.text(report.url), findsOneWidget);
    expect(harness.reportFiles.receipts.single.id, id);

    await tester.tap(byId('s12.export.copy'));
    await tester.pumpAndSettle();
    expect(copied, [report.url]);
    expect(find.text('Đã chép đường dẫn tệp.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S12 says when the PDF cannot be made and shows no file', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    harness.reportFiles.fail = true;
    await harness.pump(tester, id);

    await tester.tap(byId('s12.export'));
    await tester.pumpAndSettle();
    expect(find.text('Không tạo được tệp PDF.'), findsOneWidget);
    expect(byId('s12.export.card'), findsNothing);
    expect(harness.reports.all, isEmpty);
  });

  testWidgets('S12 lists the receipts exported earlier for this order and copies their link', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    final copied = _mockClipboard(tester);
    final saved = await harness.reports.save(
      uid: 'u1',
      fileName: 'breakbite-bien-nhan-cu.pdf',
      file: const UploadedFile(url: 'https://files.invalid/old.pdf', publicId: 'old', sizeBytes: 2048),
      orderId: id,
    );
    await harness.reports.save(
      uid: 'u1',
      fileName: 'don-khac.pdf',
      file: const UploadedFile(url: 'https://files.invalid/other.pdf', publicId: 'other', sizeBytes: 1024),
      orderId: 'other-order',
    );
    await harness.pump(tester, id);

    expect(byId('s12.receipts'), findsOneWidget);
    expect(byId('s12.receipt.${saved.valueOrNull!.id}'), findsOneWidget);
    expect(find.text('breakbite-bien-nhan-cu.pdf'), findsOneWidget);
    expect(find.text('don-khac.pdf'), findsNothing);

    await tester.tap(find.byTooltip('Chép đường dẫn tệp breakbite-bien-nhan-cu.pdf'));
    await tester.pumpAndSettle();
    expect(copied, ['https://files.invalid/old.pdf']);
  });

  testWidgets('S12 back goes to the orders list when it was opened without a history', (tester) async {
    final harness = _Harness();
    final id = await harness.deliveredOrder();
    await harness.pump(tester, id);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('ORDERS'), findsOneWidget);
  });

  testWidgets('S12 shows the loading state while the order has not arrived', (tester) async {
    await _Harness(orders: _NeverLoads()).pump(tester, 'A-204', settle: false);
    expect(find.text('Đang tải đơn hàng…'), findsOneWidget);
  });

  testWidgets('S12 shows an error with a retry when the order cannot be loaded', (tester) async {
    await _Harness(orders: _FailingOrders()).pump(tester, 'A-204');
    expect(byId('s12.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('S12 shows the empty state for an unknown order and goes to the orders list', (tester) async {
    await _Harness().pump(tester, 'nope');
    expect(byId('s12.empty'), findsOneWidget);
    expect(find.text('Không tìm thấy đơn này.'), findsOneWidget);
    await tester.tap(find.text('Xem đơn hàng'));
    await tester.pumpAndSettle();
    expect(find.text('ORDERS'), findsOneWidget);
  });
}
