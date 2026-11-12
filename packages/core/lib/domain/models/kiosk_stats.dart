import 'package:breakbite_core/domain/models/order.dart';

/// The figures of K11 for one kiosk since the start of a shift.
class KioskStats {
  const KioskStats({
    required this.deliveredCount,
    required this.revenueVnd,
    required this.cancelledCount,
    required this.activeCount,
    this.averagePrepSeconds,
    this.ordersByHour = const {},
    this.chartTruncated = false,
  });

  /// Figures from the orders themselves, for repositories that hold them all (the fake, tests). The Firestore
  /// repository counts on the server instead and only builds the chart from the newest orders.
  factory KioskStats.fromOrders(Iterable<Order> orders) {
    var delivered = 0, revenue = 0, cancelled = 0, active = 0;
    final prep = <int>[];
    for (final o in orders) {
      switch (o.status) {
        case OrderStatus.delivered:
          delivered++;
          revenue += o.totalVnd;
          if (o.prepSeconds != null) prep.add(o.prepSeconds!);
        case OrderStatus.cancelled:
          cancelled++;
        case OrderStatus.pending || OrderStatus.preparing || OrderStatus.ready:
          active++;
      }
    }
    return KioskStats(
      deliveredCount: delivered,
      revenueVnd: revenue,
      cancelledCount: cancelled,
      activeCount: active,
      averagePrepSeconds: prep.isEmpty ? null : prep.reduce((a, b) => a + b) / prep.length,
      ordersByHour: hourlyCounts(orders),
    );
  }

  /// Orders placed in each hour of the day (0 to 23), cancelled ones left out.
  static Map<int, int> hourlyCounts(Iterable<Order> orders) {
    final counts = <int, int>{};
    for (final o in orders) {
      if (o.status == OrderStatus.cancelled) continue;
      counts.update(o.createdAt.hour, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// The busiest hour, `null` when there is no order.
  int? get peakHour => ordersByHour.isEmpty
      ? null
      : ordersByHour.entries.reduce((a, b) => b.value > a.value || (b.value == a.value && b.key < a.key) ? b : a).key;

  /// No order yet.
  static const empty = KioskStats(deliveredCount: 0, revenueVnd: 0, cancelledCount: 0, activeCount: 0);

  /// Orders that were handed over: they are what was sold.
  final int deliveredCount;

  /// The total of the delivered orders, after vouchers.
  final int revenueVnd;
  final int cancelledCount;

  /// Pending, being prepared or ready.
  final int activeCount;

  /// Average of `readyAt − acceptedAt` over the delivered orders, `null` when none has it.
  final double? averagePrepSeconds;

  /// Orders placed in each hour of the day (0 to 23) that were not cancelled, for the chart.
  final Map<int, int> ordersByHour;

  /// The chart was built from the newest orders only because the shift had more than it reads.
  final bool chartTruncated;

  int get totalCount => deliveredCount + cancelledCount + activeCount;
}
