import 'package:breakbite/domain/models/cart_item.dart';

class Cart {
  const Cart({this.kioskId, this.items = const [], this.voucherCode, this.pickupSlotId, this.pickupAt});

  static const empty = Cart();
  static const maxLines = 30;
  static const maxQuantity = 99;

  final String? kioskId;
  final List<CartItem> items;
  final String? voucherCode;
  final String? pickupSlotId;
  final DateTime? pickupAt;

  bool get isEmpty => items.isEmpty;

  int get itemCount => items.fold(0, (sum, e) => sum + e.quantity);

  int get subtotalVnd => items.fold(0, (sum, e) => sum + e.lineTotalVnd);
}
