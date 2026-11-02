import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/domain/models/models.dart';

import 'fakes/fakes.dart';

const _combo = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000);
const _tea = CartItem(itemId: 'm3', name: 'Trà Đào Chanh Sả', priceVnd: 20000);
const _noodles = CartItem(itemId: 'm2', name: 'Mì Trộn Gà Cay Hàn Quốc', priceVnd: 35000);

/// Orders of the fake customer ("Minh Quân") at Kiosk Q9 · Tầng 2, in every state, so the order screens
/// (history, detail, review, report a problem, pickup code, edit) and the kiosk's shift statistics have
/// something to show: `flutter run -t dev/main_dev.dart --dart-define=DEV_SEED=true`.
Future<void> seedDevOrders(AppDependencies deps) async {
  final orders = deps.orders as FakeOrderRepository;
  Future<Order> place(List<CartItem> items, {PaymentMethod method = PaymentMethod.momo}) async {
    final id = (await orders.placeOrder(
      OrderDraft(
        uid: 'dev-user',
        customerName: 'Minh Quân',
        kioskId: 'q9-t2',
        kioskName: 'Kiosk Q9 · Tầng 2',
        items: items,
        paymentMethod: method,
      ),
    )).valueOrNull!;
    return orders.all.firstWhere((o) => o.id == id);
  }

  Order current(Order o) => orders.all.firstWhere((e) => e.id == o.id);

  Future<void> deliver(Order o) async {
    await orders.accept(o, readyIn: const Duration(minutes: 4));
    await orders.markReady(current(o));
    await orders.deliver(current(o));
  }

  await deliver(await place([_combo, _tea]));
  await deliver(await place([_noodles]));
  await deliver(await place([_combo], method: PaymentMethod.cash));
  await orders.cancelMyOrder(await place([_tea]));
  final ready = await place([_combo, _noodles]);
  await orders.accept(ready, readyIn: const Duration(minutes: 4));
  await orders.markReady(current(ready));
  await place([_noodles, _tea], method: PaymentMethod.cash);
}
