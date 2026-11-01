import 'package:breakbite/domain/models/cart_item.dart';
import 'package:breakbite/domain/models/voucher.dart';

class OrderPricing {
  const OrderPricing({required this.subtotalVnd, required this.discountVnd});

  final int subtotalVnd;
  final int discountVnd;

  int get totalVnd => subtotalVnd - discountVnd;
}

OrderPricing priceOrder(List<CartItem> items, {Voucher? voucher, required DateTime now}) {
  final subtotal = items.fold(0, (sum, e) => sum + e.lineTotalVnd);
  return OrderPricing(subtotalVnd: subtotal, discountVnd: voucher?.discountFor(subtotal, now) ?? 0);
}
