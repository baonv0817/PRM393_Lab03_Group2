import 'package:breakbite/ui/order_manage/view_models/order_cancelled_view_model.dart';
import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

class _FailingOrders extends FakeOrderRepository {
  @override
  Stream<Order?> watchOrder(String id) => Stream.error(const NetworkException());
}

class _Setup {
  _Setup(this.orders)
    : cart = FakeCartRepository(),
      session = InMemorySessionRepository(),
      analytics = FakeAnalyticsService(),
      crash = FakeCrashService();

  final FakeOrderRepository orders;
  final FakeCartRepository cart;
  final InMemorySessionRepository session;
  final FakeAnalyticsService analytics;
  final FakeCrashService crash;

  OrderCancelledViewModel viewModel(String orderId) => OrderCancelledViewModel(
    orders: orders,
    cart: cart,
    session: session,
    analytics: analytics,
    crash: crash,
    uid: 'u1',
    orderId: orderId,
  );
}

Future<(_Setup, String)> _cancelledByCustomer(PaymentMethod method) async {
  final setup = _Setup(FakeOrderRepository());
  final id = await placeTestOrder(setup.orders, uid: 'u1', method: method);
  await setup.orders.cancelMyOrder(setup.orders.all.single, reason: 'Khách huỷ trên ứng dụng');
  return (setup, id);
}

void main() {
  group('OrderCancelledViewModel', () {
    test('a paid order cancelled by the customer says so, shows no reason and promises the refund', () async {
      final (setup, id) = await _cancelledByCustomer(PaymentMethod.momo);
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<Order>>());
      expect(vm.whoLine, 'Bạn đã huỷ đơn này.');
      expect(vm.reasonLine, isNull);
      expect(vm.refunded, isTrue);
      expect(vm.refundLine, 'Hoàn 39.000đ về Ví MoMo trong khoảng 30 giây.');
      expect(vm.itemsLine, 'Combo ×1');
      expect(vm.totalLine, 'Tổng 39.000đ');
      expect(vm.cancelledAtLine, startsWith('Huỷ lúc '));
      vm.dispose();
    });

    test('a cash order that was never paid has nothing to refund', () async {
      final (setup, id) = await _cancelledByCustomer(PaymentMethod.cash);
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      expect(vm.refunded, isFalse);
      expect(vm.refundLine, 'Bạn chưa trả tiền cho đơn này nên không có khoản nào cần hoàn.');
      vm.dispose();
    });

    test('a rejection by the kiosk shows the reason the kiosk gave', () async {
      final setup = _Setup(FakeOrderRepository());
      final id = await placeTestOrder(setup.orders, uid: 'u1');
      await setup.orders.reject(setup.orders.all.single, reason: 'Hết nguyên liệu');
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      expect(vm.whoLine, 'Kiosk đã từ chối đơn này.');
      expect(vm.reasonLine, 'Lý do: Hết nguyên liệu');
      vm.dispose();
    });

    test('the screen follows the order live: a cancellation that arrives later replaces the empty state', () async {
      final setup = _Setup(FakeOrderRepository());
      final id = await placeTestOrder(setup.orders, uid: 'u1');
      final vm = setup.viewModel(id);
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<Order>>());
      expect(vm.notCancelled, isTrue);

      await setup.orders.cancelMyOrder(setup.orders.all.single);
      await pumpEventQueue();
      expect(vm.state, isA<ViewData<Order>>());
      expect(vm.notCancelled, isFalse);
      vm.dispose();
    });

    test('an order that is still open is not shown as cancelled and points to S07', () async {
      final setup = _Setup(FakeOrderRepository());
      final id = await placeTestOrder(setup.orders, uid: 'u1');
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<Order>>());
      expect((vm.state as ViewEmpty<Order>).message, OrderCancelledViewModel.notCancelledMessage);
      expect(vm.notCancelled, isTrue);
      vm.dispose();
    });

    test('an unknown order id is the empty state', () async {
      final vm = _Setup(FakeOrderRepository()).viewModel('nope');
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<Order>>());
      expect((vm.state as ViewEmpty<Order>).message, OrderCancelledViewModel.notFoundMessage);
      expect(vm.notCancelled, isFalse);
      vm.dispose();
    });

    test('a failed load is an error with the reason, it is recorded, and retry reloads', () async {
      final setup = _Setup(_FailingOrders());
      final vm = setup.viewModel('A-204');
      await pumpEventQueue();

      expect(vm.state, isA<ViewError<Order>>());
      expect((vm.state as ViewError<Order>).message, const NetworkException().message);
      expect(setup.crash.errors, hasLength(1));

      vm.load();
      expect(vm.state, isA<ViewLoading<Order>>());
      await pumpEventQueue();
      expect(vm.state, isA<ViewError<Order>>());
      vm.dispose();
    });

    test('reordering puts the items back in the cart, selects the kiosk and logs the event', () async {
      final (setup, id) = await _cancelledByCustomer(PaymentMethod.momo);
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      final result = await vm.reorder.execute();
      expect(result, isA<Ok<int>>());
      expect((result! as Ok<int>).value, 1);
      expect(setup.cart.current('u1').items.single.itemId, 'm1');
      expect(setup.cart.current('u1').kioskId, 'q9-t2');
      expect(setup.session.selectedKioskId, 'q9-t2');
      final event = setup.analytics.events.singleWhere((e) => e.name == 'reorder');
      expect(event.params, {'order_id': id, 'item_count': 1});
      vm.dispose();
    });

    test('reordering before the order has loaded fails with a message instead of crashing', () async {
      final vm = _Setup(FakeOrderRepository()).viewModel('nope');
      await pumpEventQueue();

      final result = await vm.reorder.execute();
      expect(result, isA<Err<int>>());
      expect((result! as Err<int>).error.message, OrderCancelledViewModel.notFoundMessage);
      vm.dispose();
    });
  });
}
