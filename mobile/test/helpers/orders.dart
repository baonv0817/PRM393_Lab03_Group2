import 'package:breakbite_core/domain/models/models.dart';

import '../../dev/fakes/fakes.dart';

Future<String> placeTestOrder(
  FakeOrderRepository orders, {
  required String uid,
  List<CartItem> items = const [CartItem(itemId: 'm1', name: 'Combo', priceVnd: 39000)],
  PaymentMethod method = PaymentMethod.momo,
  String kioskId = 'q9-t2',

  /// D40: a gateway order is created unpaid; by default the helper also pays it, like the gateway does.
  bool pay = true,
}) async {
  final result = await orders.placeOrder(
    OrderDraft(
      uid: uid,
      customerName: 'Khách',
      kioskId: kioskId,
      kioskName: 'Kiosk',
      items: items,
      paymentMethod: method,
    ),
  );
  final id = result.valueOrNull!;
  if (pay && method != PaymentMethod.cash) await orders.payOrder(id);
  return id;
}
