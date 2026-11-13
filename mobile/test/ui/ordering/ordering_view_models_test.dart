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

    test('a gateway that expires cancels the unpaid order, keeps the cart and suggests the next method', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      final orders = FakeOrderRepository(cart: cart);
      final vm = build(cart, orders);
      await pumpEventQueue();
      await vm.place.execute();
      expect(vm.gatewayDeadline, _now.add(CheckoutViewModel.gatewayTime));
      expect(vm.unpaidOrderId, orders.all.single.id);
      expect(vm.canPlace, isFalse);
      await vm.failGateway(GatewayOutcome.expired);
      expect(vm.failure?.method, PaymentMethod.momo);
      expect(vm.failure?.outcome, GatewayOutcome.expired);
      expect(vm.methods, isNot(contains(PaymentMethod.momo)));
      expect(vm.method, PaymentMethod.vnpay);
      expect(vm.unpaidOrderId, isNull);
      final cancelled = orders.all.single;
      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.cancelledBy, CancelledBy.customer);
      expect(cancelled.cancelReason, CheckoutViewModel.unpaidCancelReason);
      expect(cancelled.paymentStatus, PaymentStatus.unpaid);
      await pumpEventQueue();
      expect(vm.items.single.itemId, 'm1');
      expect(vm.canPlace, isTrue);
      vm.dispose();
    });

    test('D40: a gateway order is created unpaid, hidden from the kiosk, then paid at the gateway', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      final orders = FakeOrderRepository(cart: cart);
      final vm = build(cart, orders);
      await pumpEventQueue();
      vm.choose(PaymentMethod.card);
      final placed = await vm.place.execute();
      final created = orders.all.single;
      expect((placed! as Ok<String>).value, created.id);
      expect(created.kioskName, 'Kiosk Q9 · Tầng 2');
      expect(created.customerName, 'Quân');
      expect(created.paymentMethod, PaymentMethod.card);
      expect(created.paymentStatus, PaymentStatus.unpaid);
      expect(created.awaitingPayment, isTrue);
      expect(await orders.watchKioskQueue('q9-t2').first, isEmpty);
      expect(await orders.accept(created, readyIn: const Duration(minutes: 5)), isA<Err<void>>());
      expect((await cart.watchCart('u1').first).items, isNotEmpty, reason: 'the cart waits for the payment');

      final paid = await vm.pay.execute();
      expect((paid! as Ok<String>).value, created.id);
      final order = orders.all.single;
      expect(order.paymentStatus, PaymentStatus.paid);
      expect(order.status, OrderStatus.pending);
      expect((await orders.watchKioskQueue('q9-t2').first).single.id, order.id);
      expect((await cart.watchCart('u1').first).items, isEmpty);
      expect(vm.unpaidOrderId, isNull);
      vm.dispose();
    });

    test('cash is placed unpaid in one step, without the gateway, and empties the cart', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      final orders = FakeOrderRepository(cart: cart);
      final vm = build(cart, orders);
      await pumpEventQueue();
      vm.choose(PaymentMethod.cash);
      await vm.place.execute();
      final order = orders.all.single;
      expect(order.paymentStatus, PaymentStatus.unpaid);
      expect(order.awaitingPayment, isFalse);
      expect(vm.gatewayDeadline, isNull);
      expect(vm.unpaidOrderId, isNull);
      expect((await cart.watchCart('u1').first).items, isEmpty);
      expect((await orders.watchKioskQueue('q9-t2').first).single.id, order.id);
      vm.dispose();
    });

    test('paying without a placed order, or twice, fails with a message', () async {
      final cart = FakeCartRepository();
      await cart.addItem('u1', kioskId: 'q9-t2', item: _tacos);
      final orders = FakeOrderRepository(cart: cart);
      final vm = build(cart, orders);
      await pumpEventQueue();
      expect(await vm.pay.execute(), isA<Err<String>>());
      await vm.place.execute();
      final id = vm.unpaidOrderId!;
      await vm.pay.execute();
      expect(await orders.payOrder(id), isA<Err<void>>());
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
      if (method != PaymentMethod.cash) await orders.payOrder(id);
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

    test('D40: a gateway order left unpaid says the kiosk has not seen it', () async {
      final orders = FakeOrderRepository();
      final id = (await orders.placeOrder(
        const OrderDraft(
          uid: 'u1',
          customerName: 'Quân',
          kioskId: 'q9-t2',
          kioskName: 'Kiosk Q9 · Tầng 2',
          items: [_tacos],
          paymentMethod: PaymentMethod.vnpay,
        ),
      ) as Ok<String>).value;
      final vm = OrderTrackingViewModel(
        orders: orders,
        menu: FakeMenuRepository(),
        crash: FakeCrashService(),
        orderId: id,
        clock: () => _now,
      );
      await pumpEventQueue();
      expect(vm.timing, startsWith('Chưa thanh toán'));
      expect(vm.canChange, isTrue);
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
