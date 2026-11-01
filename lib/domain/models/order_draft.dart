import 'package:breakbite/domain/models/cart_item.dart';
import 'package:breakbite/domain/models/order.dart';

class OrderDraft {
  const OrderDraft({
    required this.uid,
    required this.customerName,
    required this.kioskId,
    required this.kioskName,
    required this.items,
    required this.paymentMethod,
    this.voucherCode,
    this.pickupSlotId,
    this.note = '',
  });

  final String uid;
  final String customerName;
  final String kioskId;
  final String kioskName;
  final List<CartItem> items;
  final PaymentMethod paymentMethod;
  final String? voucherCode;
  final String? pickupSlotId;
  final String note;
}
