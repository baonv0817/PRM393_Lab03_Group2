sealed class VoucherDiscount {
  const VoucherDiscount();

  int amountFor(int subtotalVnd);
}

final class FixedDiscount extends VoucherDiscount {
  const FixedDiscount(this.amountVnd);

  final int amountVnd;

  @override
  int amountFor(int subtotalVnd) => amountVnd < subtotalVnd ? amountVnd : subtotalVnd;
}

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

enum VoucherProblem { inactive, notStarted, expired, outsideActiveHours, belowMinimum }

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

  final String code;
  final String title;
  final VoucherDiscount discount;
  final int minOrderVnd;
  final DateTime? startsAt;
  final DateTime expiresAt;
  final String? activeFrom;
  final String? activeTo;
  final bool active;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);

  bool isWithinActiveHours(DateTime now) {
    final from = _minutes(activeFrom);
    final to = _minutes(activeTo);
    if (from == null || to == null) return true;
    final vietnam = now.toUtc().add(const Duration(hours: 7));
    final current = vietnam.hour * 60 + vietnam.minute;
    return current >= from && current < to;
  }

  VoucherProblem? problemFor(int subtotalVnd, DateTime now) {
    if (!active) return VoucherProblem.inactive;
    if (startsAt != null && now.isBefore(startsAt!)) return VoucherProblem.notStarted;
    if (isExpired(now)) return VoucherProblem.expired;
    if (!isWithinActiveHours(now)) return VoucherProblem.outsideActiveHours;
    if (subtotalVnd < minOrderVnd) return VoucherProblem.belowMinimum;
    return null;
  }

  int discountFor(int subtotalVnd, DateTime now) =>
      problemFor(subtotalVnd, now) == null ? discount.amountFor(subtotalVnd) : 0;

  static int? _minutes(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return h == null || m == null ? null : h * 60 + m;
  }
}
