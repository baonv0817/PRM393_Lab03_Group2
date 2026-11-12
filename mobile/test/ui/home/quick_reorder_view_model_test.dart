import 'package:breakbite/ui/home/view_models/quick_reorder_view_model.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

class _OfflineOrders extends FakeOrderRepository {
  @override
  Stream<List<Order>> watchMyOrders(String uid, {int limit = 20}) => Stream.error(const NetworkException());
}

QuickReorderViewModel _vm(FakeOrderRepository orders, FakeCartRepository cart) => QuickReorderViewModel(
  orders: orders,
  cart: cart,
  analytics: FakeAnalyticsService(),
  crash: FakeCrashService(),
  uid: 'u',
);

void main() {
  group('QuickReorderViewModel (S14)', () {
    test('is empty with an explanation for a customer without orders', () async {
      final vm = _vm(FakeOrderRepository(), FakeCartRepository());
      await pumpEventQueue();
      expect((vm.state as ViewEmpty).message, QuickReorderViewModel.emptyMessage);
      expect(vm.chosen, isNull);
    });

    test('offers the newest orders first, at most five, and never a cancelled one', () async {
      final orders = FakeOrderRepository();
      for (var i = 0; i < 7; i++) {
        await placeTestOrder(orders, uid: 'u');
      }
      await orders.cancelMyOrder(orders.all.last);
      final vm = _vm(orders, FakeCartRepository());
      await pumpEventQueue();

      final list = (vm.state as ViewData<List<Order>>).data;
      expect(list, hasLength(QuickReorderViewModel.maxOrders));
      expect(list.any((o) => o.status == OrderStatus.cancelled), isFalse);
      expect(vm.chosen?.id, list.first.id, reason: 'the newest is chosen until the customer taps another');
    });

    test('choosing another order changes the amount on the main button and what goes in the cart', () async {
      final orders = FakeOrderRepository();
      final cart = FakeCartRepository();
      await placeTestOrder(
        orders,
        uid: 'u',
        items: const [CartItem(itemId: 'm1', name: 'Combo', priceVnd: 39000)],
      );
      await placeTestOrder(
        orders,
        uid: 'u',
        items: const [CartItem(itemId: 'm3', name: 'Trà', priceVnd: 20000)],
      );
      final vm = _vm(orders, cart);
      await pumpEventQueue();

      expect(vm.chosenTotalVnd, 20000);
      vm.choose((vm.state as ViewData<List<Order>>).data.last);
      expect(vm.chosenTotalVnd, 39000);
      final result = await vm.reorder.execute();
      expect(result, isA<Ok<int>>());
      expect(cart.current('u').items.map((i) => i.itemId), ['m1']);
    });

    test('a failed list shows an error with a retry', () async {
      final vm = _vm(_OfflineOrders(), FakeCartRepository());
      await pumpEventQueue();
      expect(vm.state, isA<ViewError<List<Order>>>());
    });
  });
}
