import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/order_manage/view_models/pickup_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

class _FailingOrders extends FakeOrderRepository {
  @override
  Stream<Order?> watchOrder(String id) => Stream.error(const NetworkException());
}

PickupViewModel _vm(FakeOrderRepository orders, {String id = 'A-204', FakeCrashService? crash}) =>
    PickupViewModel(orders: orders, crash: crash ?? FakeCrashService(), orderId: id);

Future<void> _accept(FakeOrderRepository orders) =>
    orders.accept(orders.all.single, readyIn: const Duration(minutes: 5));

void main() {
  group('PickupViewModel', () {
    test(
      'a new order has a usable code, in two groups of three digits, and says it works once the food is ready',
      () async {
        final orders = FakeOrderRepository();
        final id = await placeTestOrder(orders, uid: 'u1');
        final vm = _vm(orders, id: id);
        await pumpEventQueue();

        expect(vm.state, isA<ViewData<Order>>());
        expect(vm.usable, isTrue);
        expect(vm.qrPayload, 'bb:$id:${orders.all.single.pickupCode}');
        expect(vm.codeText, '100 204');
        expect(vm.statusLine, 'Kiosk chưa nhận đơn. Mã dùng được khi món sẵn sàng.');
        expect(vm.summaryLine, 'Combo ×1 · 39.000đ');
        vm.dispose();
      },
    );

    test('while the kitchen cooks it gives the promised time, then says to show the code when ready', () async {
      final orders = FakeOrderRepository();
      final id = await placeTestOrder(orders, uid: 'u1');
      final vm = _vm(orders, id: id);
      await pumpEventQueue();

      await _accept(orders);
      await pumpEventQueue();
      final readyBy = orders.all.single.readyBy!;
      expect(vm.statusLine, 'Kiosk đang làm món, dự kiến sẵn sàng lúc ${formatTime(readyBy)}.');
      expect(vm.usable, isTrue);

      await orders.markReady(orders.all.single);
      await pumpEventQueue();
      expect(vm.statusLine, 'Món đã sẵn sàng. Đưa mã này cho kiosk.');
      expect(vm.usable, isTrue);
      vm.dispose();
    });

    test('once the order is delivered the code is spent and the screen says when it was received', () async {
      final orders = FakeOrderRepository();
      final id = await placeTestOrder(orders, uid: 'u1');
      await _accept(orders);
      await orders.markReady(orders.all.single);
      final vm = _vm(orders, id: id);
      await pumpEventQueue();
      expect(vm.usable, isTrue);

      await orders.deliver(orders.all.single);
      await pumpEventQueue();
      expect(vm.usable, isFalse);
      expect(vm.statusLine, 'Bạn đã nhận món lúc ${formatTime(orders.all.single.deliveredAt!)}.');
      vm.dispose();
    });

    test('a cancelled order has no usable code', () async {
      final orders = FakeOrderRepository();
      final id = await placeTestOrder(orders, uid: 'u1');
      await orders.cancelMyOrder(orders.all.single);
      final vm = _vm(orders, id: id);
      await pumpEventQueue();

      expect(vm.usable, isFalse);
      expect(vm.statusLine, 'Đơn đã huỷ nên mã không còn dùng được.');
      vm.dispose();
    });

    test('a cash order shows the amount to pay at the counter while the code is usable, a paid one does not', () async {
      final orders = FakeOrderRepository();
      final cash = await placeTestOrder(orders, uid: 'u1', method: PaymentMethod.cash);
      final paid = await placeTestOrder(orders, uid: 'u1');
      final cashVm = _vm(orders, id: cash);
      final paidVm = _vm(orders, id: paid);
      await pumpEventQueue();

      expect(cashVm.paymentLine, 'Trả tại quầy khi nhận: 39.000đ');
      expect(paidVm.paymentLine, isNull);

      await orders.cancelMyOrder(orders.all.firstWhere((o) => o.id == cash));
      await pumpEventQueue();
      expect(cashVm.paymentLine, isNull);
      cashVm.dispose();
      paidVm.dispose();
    });

    test('an unknown order id is the empty state', () async {
      final vm = _vm(FakeOrderRepository(), id: 'nope');
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<Order>>());
      expect((vm.state as ViewEmpty<Order>).message, PickupViewModel.notFoundMessage);
      expect(vm.usable, isFalse);
      expect(vm.codeText, '');
      vm.dispose();
    });

    test('a failed load is an error with the reason, it is recorded, and retry loads again', () async {
      final crash = FakeCrashService();
      final vm = _vm(_FailingOrders(), crash: crash);
      await pumpEventQueue();

      expect(vm.state, isA<ViewError<Order>>());
      expect((vm.state as ViewError<Order>).message, const NetworkException().message);
      expect(crash.errors, hasLength(1));

      vm.load();
      expect(vm.state, isA<ViewLoading<Order>>());
      await pumpEventQueue();
      expect(vm.state, isA<ViewError<Order>>());
      vm.dispose();
    });
  });
}
