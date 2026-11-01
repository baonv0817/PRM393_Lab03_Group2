import 'package:breakbite/domain/models/models.dart';

import '../../dev/fakes/fakes.dart';

Future<String> placeTestOrder(
  FakeOrderRepository orders, {
  required String uid,
  List<CartItem> items = const [CartItem(itemId: 'm1', name: 'Combo', priceVnd: 39000)],
  PaymentMethod method = PaymentMethod.momo,
  String kioskId = 'q9-t2',
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
  return result.valueOrNull!;
}
