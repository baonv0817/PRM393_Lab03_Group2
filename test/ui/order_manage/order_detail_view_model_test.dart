import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/order_manage/view_models/order_detail_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

class _FailingOrders extends FakeOrderRepository {
  @override
  Stream<Order?> watchOrder(String id) => Stream.error(const NetworkException());
}

class _OfflineStorage extends FakeStorageService {
  @override
  Future<Result<UploadedFile>> upload({
    required UploadFolder folder,
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async => const Result.error(NetworkException());
}

const _combo = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000, quantity: 2, note: 'Ít cay');
const _tea = CartItem(itemId: 'm2', name: 'Trà đào', priceVnd: 25000);

class _Setup {
  _Setup({FakeOrderRepository? orders, FakeStorageService? storage, this.uid = 'u1'})
    : orders = orders ?? FakeOrderRepository(vouchers: {for (final v in fakeVouchers) v.code: v}),
      storage = storage ?? FakeStorageService();

  final FakeOrderRepository orders;
  final FakeStorageService storage;
  final String uid;
  final cart = FakeCartRepository();
  final session = InMemorySessionRepository();
  final reportFiles = FakeReportFileService();
  final reports = FakeReportRepository();
  final analytics = FakeAnalyticsService();
  final crash = FakeCrashService();

  OrderDetailViewModel viewModel(String orderId) => OrderDetailViewModel(
    orders: orders,
    cart: cart,
    session: session,
    storage: storage,
    reportFiles: reportFiles,
    reports: reports,
    analytics: analytics,
    crash: crash,
    uid: uid,
    customerName: 'Nguyễn Minh Quân',
    orderId: orderId,
    clock: () => DateTime(2026, 11, 2, 10),
  );

  /// A MoMo order of 2 combos with a note and a tea, with the BBSTUDENT voucher: 103.000đ − 10.000đ.
  Future<String> placeDiscounted() async {
    final result = await orders.placeOrder(
      const OrderDraft(
        uid: 'u1',
        customerName: 'Khách',
        kioskId: 'q9-t2',
        kioskName: 'Kiosk Q9 · Tầng 2',
        items: [_combo, _tea],
        paymentMethod: PaymentMethod.momo,
        voucherCode: 'BBSTUDENT',
        note: 'Gói riêng',
      ),
    );
    return result.valueOrNull!;
  }

  Future<void> deliver(String id) async {
    Order current() => orders.all.firstWhere((o) => o.id == id);
    await orders.accept(current(), readyIn: const Duration(minutes: 5));
    await orders.markReady(current());
    await orders.deliver(current());
  }
}

void main() {
  group('OrderDetailViewModel', () {
    test('a delivered order shows its steps, lines, bill, payment, pickup and note', () async {
      final setup = _Setup();
      final id = await setup.placeDiscounted();
      await setup.deliver(id);
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<Order>>());
      expect(vm.statusLabel, 'Hoàn tất');
      expect(vm.isActive, isFalse);
      expect(vm.isCancelled, isFalse);
      expect(vm.timeline.map((r) => r.label), ['Đặt đơn', 'Kiosk nhận đơn', 'Món sẵn sàng', 'Nhận món']);
      expect(vm.timeline.first.value, formatDateTime(vm.order!.createdAt));
      expect(vm.lines.map((l) => (l.name, l.quantity, l.price, l.note)), [
        ('Combo Tacos Bò Phô Mai', '×2', '78.000đ', 'Ít cay'),
        ('Trà đào', '×1', '25.000đ', null),
      ]);
      expect(vm.amounts.map((r) => (r.id, r.label, r.value)), [
        ('subtotal', 'Tạm tính', '103.000đ'),
        ('discount', 'Giảm giá (BBSTUDENT)', '−10.000đ'),
        ('total', 'Tổng cộng', '93.000đ'),
      ]);
      expect(vm.amounts.last.strong, isTrue);
      expect(vm.paymentLine, 'Ví MoMo · Đã thanh toán');
      expect(vm.pickupLine, 'Nhận ngay khi sẵn sàng');
      expect(vm.noteLine, 'Ghi chú cho bếp: Gói riêng');
      vm.dispose();
    });

    test('an order without a voucher, note or finished steps keeps those rows out', () async {
      final setup = _Setup();
      final id = await placeTestOrder(setup.orders, uid: 'u1');
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      expect(vm.isActive, isTrue);
      expect(vm.timeline.map((r) => r.label), ['Đặt đơn']);
      expect(vm.amounts.map((r) => r.id), ['subtotal', 'total']);
      expect(vm.noteLine, isNull);
      vm.dispose();
    });

    test('a cancelled paid order shows the cancel step and that the money comes back', () async {
      final setup = _Setup();
      final id = await placeTestOrder(setup.orders, uid: 'u1');
      await setup.orders.cancelMyOrder(setup.orders.all.single);
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      expect(vm.isCancelled, isTrue);
      expect(vm.isActive, isFalse);
      expect(vm.statusLabel, 'Đã huỷ');
      expect(vm.timeline.map((r) => r.label), ['Đặt đơn', 'Huỷ đơn']);
      expect(vm.paymentLine, 'Ví MoMo · Được hoàn tiền');
      vm.dispose();
    });

    test('an unknown order id is the empty state', () async {
      final vm = _Setup().viewModel('nope');
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<Order>>());
      expect((vm.state as ViewEmpty<Order>).message, OrderDetailViewModel.notFoundMessage);
      vm.dispose();
    });

    test('a failed load is an error with the reason, it is recorded, and retry reloads', () async {
      final setup = _Setup(orders: _FailingOrders());
      final vm = setup.viewModel('A-204');
      await pumpEventQueue();

      expect(vm.state, isA<ViewError<Order>>());
      expect((vm.state as ViewError<Order>).message, const NetworkException().message);
      expect(setup.crash.errors, isNotEmpty);

      vm.load();
      expect(vm.state, isA<ViewLoading<Order>>());
      await pumpEventQueue();
      expect(vm.state, isA<ViewError<Order>>());
      vm.dispose();
    });

    test('reordering puts the items back in the cart and selects the kiosk', () async {
      final setup = _Setup();
      final id = await setup.placeDiscounted();
      await setup.deliver(id);
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      final result = await vm.reorder.execute();
      expect((result! as Ok<int>).value, 2);
      expect(setup.cart.current('u1').items.map((i) => i.itemId), containsAll(['m1', 'm2']));
      expect(setup.session.selectedKioskId, 'q9-t2');
      expect(setup.analytics.events.map((e) => e.name), contains('reorder'));
      vm.dispose();
    });

    group('exporting the receipt', () {
      test('generates the PDF, uploads it with progress, saves it for this order and logs the export', () async {
        final setup = _Setup();
        final id = await setup.placeDiscounted();
        await setup.deliver(id);
        final vm = setup.viewModel(id);
        await pumpEventQueue();
        final stages = <ReceiptStage>[];
        vm.addListener(() {
          if (stages.isEmpty || stages.last != vm.stage) stages.add(vm.stage);
        });

        final result = await vm.exportReceipt.execute();
        await pumpEventQueue();

        final report = (result! as Ok<Report>).value;
        expect(stages, containsAllInOrder([ReceiptStage.generating, ReceiptStage.uploading, ReceiptStage.saving]));
        expect(vm.stage, ReceiptStage.idle);
        expect(vm.uploadProgress, 1);
        expect(setup.reportFiles.receipts.single.id, id);
        expect(setup.storage.uploads.single.url, contains('/reports/u1/'));
        expect(report.orderId, id);
        expect(report.uid, 'u1');
        expect(vm.lastReceipt, report);
        expect(vm.receipts.map((r) => r.id), [report.id]);
        final event = setup.analytics.events.singleWhere((e) => e.name == 'export_report');
        expect(event.params, {'file_size_kb': report.sizeKb, 'source': 'order_detail'});
        vm.dispose();
      });

      test('lists only the receipts of this order', () async {
        final setup = _Setup();
        final first = await placeTestOrder(setup.orders, uid: 'u1');
        final second = await placeTestOrder(setup.orders, uid: 'u1');
        final vmFirst = setup.viewModel(first);
        await pumpEventQueue();
        await vmFirst.exportReceipt.execute();
        await pumpEventQueue();

        final vmSecond = setup.viewModel(second);
        await pumpEventQueue();
        expect(vmFirst.receipts, hasLength(1));
        expect(vmSecond.receipts, isEmpty);
        vmFirst.dispose();
        vmSecond.dispose();
      });

      test('a PDF that cannot be made fails with a message, uploads nothing and is recorded', () async {
        final setup = _Setup();
        final id = await placeTestOrder(setup.orders, uid: 'u1');
        setup.reportFiles.fail = true;
        final vm = setup.viewModel(id);
        await pumpEventQueue();

        final result = await vm.exportReceipt.execute();
        expect((result! as Err<Report>).error.message, 'Không tạo được tệp PDF.');
        expect(vm.stage, ReceiptStage.idle);
        expect(setup.storage.uploads, isEmpty);
        expect(setup.crash.errors, hasLength(1));
        expect(setup.analytics.events.where((e) => e.name == 'export_report'), isEmpty);
        vm.dispose();
      });

      test('losing the connection during the upload fails with a message and saves nothing', () async {
        final setup = _Setup(storage: _OfflineStorage());
        final id = await placeTestOrder(setup.orders, uid: 'u1');
        final vm = setup.viewModel(id);
        await pumpEventQueue();

        final result = await vm.exportReceipt.execute();
        expect((result! as Err<Report>).error.message, const NetworkException().message);
        expect(vm.stage, ReceiptStage.idle);
        expect(setup.reports.all, isEmpty);
        expect(vm.lastReceipt, isNull);
        vm.dispose();
      });

      test('a failure when saving the file info is reported and nothing is listed', () async {
        final setup = _Setup();
        final id = await placeTestOrder(setup.orders, uid: 'u1');
        setup.reports.failNextSave = const PermissionDeniedException();
        final vm = setup.viewModel(id);
        await pumpEventQueue();

        final result = await vm.exportReceipt.execute();
        expect(result, isA<Err<Report>>());
        expect(vm.receipts, isEmpty);
        expect(vm.lastReceipt, isNull);

        final retry = await vm.exportReceipt.execute();
        expect(retry, isA<Ok<Report>>());
        vm.dispose();
      });

      test('a signed-out user is asked to sign in and nothing is generated', () async {
        final setup = _Setup(uid: '');
        final id = await placeTestOrder(setup.orders, uid: 'u1');
        final vm = setup.viewModel(id);
        await pumpEventQueue();

        final result = await vm.exportReceipt.execute();
        expect((result! as Err<Report>).error.message, 'Đăng nhập để xuất biên nhận.');
        expect(setup.reportFiles.receipts, isEmpty);
        vm.dispose();
      });

      test('exporting before the order has loaded fails with a message instead of crashing', () async {
        final vm = _Setup().viewModel('nope');
        await pumpEventQueue();

        final result = await vm.exportReceipt.execute();
        expect((result! as Err<Report>).error.message, OrderDetailViewModel.notFoundMessage);
        vm.dispose();
      });
    });
  });
}
