class Voucher {
  const Voucher({
    required this.code,
    required this.discountVnd,
    required this.expiresAt,
    required this.minOrderVnd,
    this.title = '',
    this.percent,
    this.maxDiscountVnd,
    this.active = true,
  });

  final String code;

  /// Fixed discount (VND). When `percent` is set, the percentage discount is used instead.
  final int discountVnd;
  final DateTime expiresAt;
  final int minOrderVnd;
  final String title;

  /// Percentage discount (1–100), capped by `maxDiscountVnd`.
  final int? percent;
  final int? maxDiscountVnd;
  final bool active;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);

  /// Discount amount for an order with subtotal `subtotalVnd`; 0 if the order does not qualify.
  int discountFor(int subtotalVnd, DateTime now) {
    if (!active || isExpired(now) || subtotalVnd < minOrderVnd) return 0;
    final raw = percent == null ? discountVnd : subtotalVnd * percent! ~/ 100;
    final capped = maxDiscountVnd == null || raw < maxDiscountVnd! ? raw : maxDiscountVnd!;
    return capped > subtotalVnd ? subtotalVnd : capped;
  }
}
