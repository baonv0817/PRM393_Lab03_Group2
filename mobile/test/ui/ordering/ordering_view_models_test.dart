import 'package:breakbite/ui/cart/view_models/cart_view_model.dart';
import 'package:breakbite/ui/checkout/view_models/checkout_view_model.dart';
import 'package:breakbite/ui/orders/view_models/order_tracking_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

class _ClosedKiosks extends FakeMenuRepository {
  @override
  Stream<List<Kiosk>> watchKiosks() => Stream.value(const [
    Kiosk(id: 'q9-t2', name: 'Kiosk Q9 · Tầng 2', open: false, waitMinutes: 0, openTime: '07:00'),
  ]);
}

const _tacos = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000);
final _now = DateTime(2026, 11, 2, 10);

void main() {
  group('CartViewModel', () {
    test('an empty cart is the empty state; items show their total and pickup time', () async {
      final cart = FakeCartRepository();
      final vm = CartViewModel(
        cart: cart,
        menu: FakeMenuRepository(),
        crash: FakeCrashService(),
        uid: 'u1',
        clock: () => _now,
      );
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<List<CartItem>>>());
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      await pumpEventQueue();
      expect(vm.items.single.itemId, 'm1');
      expect(vm.pricing.totalVnd, 39000);
      expect(vm.readyAt, _now.add(const Duration(minutes: 6)));
      expect(vm.canCheckout, isTrue);
      vm.dispose();
    });

    test('D42: each line shows the photo of its item from the kiosk menu', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      final vm = CartViewModel(
        cart: cart,
        menu: FakeMenuRepository(),
        crash: FakeCrashService(),
        uid: 'u1',
        clock: () => _now,
      );
      await pumpEventQueue();
      expect(vm.imageOf('m1'), 'assets/images/menu/tacos-bo.jpg');
      expect(vm.imageOf('unknown'), isNull);
      vm.dispose();
    });

    test('a voucher below its minimum blocks checkout until it is removed', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      await cart.setVoucher('u1', 'BBSTUDENT');
      final vm = CartViewModel(
        cart: cart,
        menu: FakeMenuRepository(),
        crash: FakeCrashService(),
        uid: 'u1',
        clock: () => _now,
      );
      await pumpEventQueue();
      expect(vm.voucherProblem, 'Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT.');
      expect(vm.canCheckout, isFalse);
      await vm.removeVoucher.execute();
      await pumpEventQueue();
      expect(vm.voucherProblem, isNull);
      expect(vm.canCheckout, isTrue);
      vm.dispose();
    });

    test('a valid voucher takes its discount off the total', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos.copyWith(quantity: 2));
      await cart.setVoucher('u1', 'BBSTUDENT');
      final vm = CartViewModel(
        cart: cart,
        menu: FakeMenuRepository(),
        crash: FakeCrashService(),
        uid: 'u1',
        clock: () => _now,
      );
      await pumpEventQueue();
      expect(vm.pricing.discountVnd, 10000);
      expect(vm.pricing.totalVnd, 68000);
      vm.dispose();
    });

    test('a closed kiosk blocks checkout with a reason', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      final vm = CartViewModel(
        cart: cart,
        menu: _ClosedKiosks(),
        crash: FakeCrashService(),
        uid: 'u1',
        clock: () => _now,
      );
      await pumpEventQueue();
      expect(vm.blocker, contains('đang tạm ngưng nhận đơn'));
      expect(vm.canCheckout, isFalse);
      vm.dispose();
    });
  });

  group('CheckoutViewModel', () {
    CheckoutViewModel build(FakeCartRepository cart, FakeOrderRepository orders, {FakeUserRepository? users}) =>
        CheckoutViewModel(
          cart: cart,
          menu: FakeMenuRepository(),
          orders: orders,
          users: users ?? FakeUserRepository(),
          analytics: FakeAnalyticsService(),
          crash: FakeCrashService(),
          uid: 'u1',
          customerName: 'Quân',
          clock: () => _now,
        );

    test('the default payment method saved in S17 is preselected', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      final users = FakeUserRepository();
      await users.setDefaultPaymentMethod('u1', PaymentMethod.cash);
      final vm = build(cart, FakeOrderRepository(cart: cart), users: users);
      await pumpEventQueue();
      expect(vm.method, PaymentMethod.cash);
      expect(vm.needsGateway, isFalse);
      vm.dispose();
    });

    test('a gateway that expires is a failure that removes that method and suggests the next', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      final vm = build(cart, FakeOrderRepository(cart: cart));
      await pumpEventQueue();
      vm.openGateway();
      expect(vm.gatewayDeadline, _now.add(CheckoutViewModel.gatewayTime));
      vm.failGateway(GatewayOutcome.expired);
      expect(vm.failure?.method, PaymentMethod.momo);
      expect(vm.failure?.outcome, GatewayOutcome.expired);
      expect(vm.methods, isNot(contains(PaymentMethod.momo)));
      expect(vm.method, PaymentMethod.vnpay);
      vm.dispose();
    });

    test('placing writes an order with the cart, the kiosk and the chosen method', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      final orders = FakeOrderRepository(cart: cart);
      final vm = build(cart, orders);
      await pumpEventQueue();
      vm.choose(PaymentMethod.card);
      final result = await vm.place.execute();
      final order = orders.all.single;
      expect((result! as Ok<String>).value, order.id);
      expect(order.kioskName, 'Kiosk Q9 · Tầng 2');
      expect(order.customerName, 'Quân');
      expect(order.paymentMethod, PaymentMethod.card);
      expect(order.paymentStatus, PaymentStatus.paid);
      vm.dispose();
    });
  });

  group('OrderTrackingViewModel', () {
    Future<(FakeOrderRepository, Order)> placed(PaymentMethod method) async {
      final orders = FakeOrderRepository();
      final id = (await orders.placeOrder(
        OrderDraft(
          uid: 'u1',
          customerName: 'Quân',
          kioskId: 'q9-t2',
          kioskName: 'Kiosk Q9 · Tầng 2',
          items: const [_tacos],
          paymentMethod: method,
        ),
      ) as Ok<String>).value;
      return (orders, orders.all.firstWhere((o) => o.id == id));
    }

    test('each status tells the customer what happens next', () async {
      final (orders, order) = await placed(PaymentMethod.momo);
      final vm = OrderTrackingViewModel(
        orders: orders,
        menu: FakeMenuRepository(),
        crash: FakeCrashService(),
        orderId: order.id,
        clock: () => order.createdAt.add(const Duration(minutes: 2)),
      );
      await pumpEventQueue();
      expect(vm.stepIndex, 0);
      expect(vm.timing, 'Chờ kiosk nhận đơn');
      expect(vm.canChange, isTrue);
      await orders.accept(vm.order!, readyIn: const Duration(minutes: 5));
      await pumpEventQueue();
      expect(vm.stepIndex, 1);
      expect(vm.timing, startsWith('Dự kiến sẵn sàng'));
      expect(vm.canChange, isFalse);
      await orders.markReady(vm.order!);
      await pumpEventQueue();
      expect(vm.timing, 'Món đã sẵn sàng, mời bạn tới quầy');
      expect(vm.badge, 'Sẵn sàng');
      vm.dispose();
    });

    test('a cash order says to pay at the counter; cancelling a paid order mentions the refund', () async {
      final (cashOrders, cash) = await placed(PaymentMethod.cash);
      final cashVm = OrderTrackingViewModel(
        orders: cashOrders,
        menu: FakeMenuRepository(),
        crash: FakeCrashService(),
        orderId: cash.id,
      );
      await pumpEventQueue();
      expect(cashVm.badge, 'Trả tại quầy');
      expect(cashVm.paymentLine, 'Trả tại quầy khi nhận: 39.000đ');
      expect(cashVm.cancelMessage, 'Chỉ huỷ được khi bếp chưa làm.');
      cashVm.dispose();

      final (paidOrders, paid) = await placed(PaymentMethod.momo);
      final vm = OrderTrackingViewModel(
        orders: paidOrders,
        menu: FakeMenuRepository(),
        crash: FakeCrashService(),
        orderId: paid.id,
      );
      await pumpEventQueue();
      expect(vm.cancelMessage, startsWith('Hoàn 39.000đ về Ví MoMo'));
      await vm.cancel.execute();
      await pumpEventQueue();
      expect(vm.order!.status, OrderStatus.cancelled);
      expect(vm.badge, 'Đã huỷ');
      vm.dispose();
    });

    test('an unknown order id is the empty state', () async {
      final vm = OrderTrackingViewModel(
        orders: FakeOrderRepository(),
        menu: FakeMenuRepository(),
        crash: FakeCrashService(),
        orderId: 'nope',
      );
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<Order>>());
      vm.dispose();
    });
  });
}
