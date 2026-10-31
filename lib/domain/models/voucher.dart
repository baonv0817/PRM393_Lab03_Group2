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

  /// Giảm cố định (VND). Khi `percent` có giá trị thì dùng giảm theo phần trăm.
  final int discountVnd;
  final DateTime expiresAt;
  final int minOrderVnd;
  final String title;

  /// Giảm theo phần trăm (1–100), kèm trần `maxDiscountVnd`.
  final int? percent;
  final int? maxDiscountVnd;
  final bool active;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);

  /// Số tiền giảm cho một đơn có tạm tính `subtotalVnd`; 0 nếu chưa đủ điều kiện.
  int discountFor(int subtotalVnd, DateTime now) {
    if (!active || isExpired(now) || subtotalVnd < minOrderVnd) return 0;
    final raw = percent == null ? discountVnd : subtotalVnd * percent! ~/ 100;
    final capped = maxDiscountVnd == null || raw < maxDiscountVnd! ? raw : maxDiscountVnd!;
    return capped > subtotalVnd ? subtotalVnd : capped;
  }
}
