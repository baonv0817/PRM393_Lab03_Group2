/// How much a voucher takes off: exactly one of two shapes, so a voucher can never be both a fixed
/// amount and a percentage. Stored as `discount: {type: 'fixed', amountVnd}` or
/// `discount: {type: 'percent', percent, maxVnd}`; the rules check the same shapes and formula.
sealed class VoucherDiscount {
  const VoucherDiscount();

  /// Amount taken off a subtotal, never more than the subtotal.
  int amountFor(int subtotalVnd);
}

final class FixedDiscount extends VoucherDiscount {
  const FixedDiscount(this.amountVnd);

  final int amountVnd;

  @override
  int amountFor(int subtotalVnd) => amountVnd < subtotalVnd ? amountVnd : subtotalVnd;
}

/// A percentage always has a cap, so a large order cannot get an unbounded discount.
final class PercentDiscount extends VoucherDiscount {
  const PercentDiscount({required this.percent, required this.maxVnd});

  final int percent;
  final int maxVnd;

  @override
  int amountFor(int subtotalVnd) {
    final raw = subtotalVnd * percent ~/ 100;
    final capped = raw < maxVnd ? raw : maxVnd;
    return capped < subtotalVnd ? capped : subtotalVnd;
  }
}

class Voucher {
  const Voucher({
    required this.code,
    required this.discount,
    required this.expiresAt,
    this.minOrderVnd = 0,
    this.title = '',
    this.startsAt,
    this.activeFrom,
    this.activeTo,
    this.active = true,
  });

  /// The upper-case code is also the document id.
  final String code;
  final String title;
  final VoucherDiscount discount;
  final int minOrderVnd;
  final DateTime? startsAt;
  final DateTime expiresAt;

  /// Daily window in Vietnam time, `"HH:mm"` (the Golden Hour code only works 10:15–10:30).
  final String? activeFrom;
  final String? activeTo;
  final bool active;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);

  /// Whether [now] (any time zone) falls inside the daily window; always true without one.
  bool isWithinActiveHours(DateTime now) {
    final from = _minutes(activeFrom);
    final to = _minutes(activeTo);
    if (from == null || to == null) return true;
    final vietnam = now.toUtc().add(const Duration(hours: 7));
    final current = vietnam.hour * 60 + vietnam.minute;
    return current >= from && current < to;
  }

  /// Discount for an order with subtotal [subtotalVnd]; 0 when the order does not qualify.
  int discountFor(int subtotalVnd, DateTime now) {
    final notStarted = startsAt != null && now.isBefore(startsAt!);
    if (!active || notStarted || isExpired(now) || !isWithinActiveHours(now) || subtotalVnd < minOrderVnd) return 0;
    return discount.amountFor(subtotalVnd);
  }

  static int? _minutes(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return h == null || m == null ? null : h * 60 + m;
  }
}
