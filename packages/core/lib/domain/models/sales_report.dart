import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/domain/models/slot_plan.dart';

/// Takings of one day (Vietnam calendar).
class DaySales {
  const DaySales({required this.day, required this.orders, required this.revenueVnd, this.revenueByKiosk = const {}});

  /// The day as `DateTime.utc(year, month, day)`.
  final DateTime day;
  final int orders;
  final int revenueVnd;

  /// The takings of the day split by kiosk id, for a stacked chart; kiosks with no takings are absent.
  final Map<String, int> revenueByKiosk;
}

/// Takings of one kiosk.
class KioskSales {
  const KioskSales({
    required this.kioskId,
    required this.kioskName,
    required this.orders,
    required this.delivered,
    required this.cancelled,
    required this.revenueVnd,
  });

  final String kioskId;
  final String kioskName;
  final int orders;
  final int delivered;
  final int cancelled;
  final int revenueVnd;
}

/// A dish and how many were sold.
class DishSales {
  const DishSales({required this.name, required this.quantity, required this.revenueVnd});

  final String name;
  final int quantity;
  final int revenueVnd;
}

/// The figures of the admin's statistics page (A08), worked out from the orders of a period. Revenue and the
/// dishes count only the orders that were handed over (`delivered`); a cancelled order is counted as such and
/// brings in nothing.
class SalesReport {
  const SalesReport({
    required this.orders,
    required this.delivered,
    required this.cancelled,
    required this.active,
    required this.revenueVnd,
    required this.averagePrepSeconds,
    required this.byDay,
    required this.byHour,
    required this.byKiosk,
    required this.topDishes,
    this.truncated = false,
  });

  /// How many dishes the "best sellers" list holds.
  static const topDishCount = 10;

  factory SalesReport.fromOrders(Iterable<Order> orders, {bool truncated = false}) {
    var placed = 0, delivered = 0, cancelled = 0, active = 0, revenue = 0;
    final prep = <int>[];
    final days = <DateTime, _DayTally>{};
    final hours = List<int>.filled(24, 0);
    final kiosks = <String, _KioskTally>{};
    final dishes = <String, ({int quantity, int revenue})>{};
    for (final o in orders) {
      placed++;
      final tally = kiosks.putIfAbsent(o.kioskId, () => _KioskTally(o.kioskName.isEmpty ? o.kioskId : o.kioskName));
      tally.orders++;
      switch (o.status) {
        case OrderStatus.delivered:
          delivered++;
          tally.delivered++;
          revenue += o.totalVnd;
          tally.revenue += o.totalVnd;
          if (o.prepSeconds != null) prep.add(o.prepSeconds!);
          for (final line in o.items) {
            dishes.update(
              line.name,
              (d) => (quantity: d.quantity + line.quantity, revenue: d.revenue + line.priceVnd * line.quantity),
              ifAbsent: () => (quantity: line.quantity, revenue: line.priceVnd * line.quantity),
            );
          }
        case OrderStatus.cancelled:
          cancelled++;
          tally.cancelled++;
        case OrderStatus.pending || OrderStatus.preparing || OrderStatus.ready:
          active++;
      }
      final vietnam = o.createdAt.toUtc().add(SlotPlan.vietnamOffset);
      final day = DateTime.utc(vietnam.year, vietnam.month, vietnam.day);
      final tallyOfDay = days.putIfAbsent(day, _DayTally.new);
      tallyOfDay.orders++;
      if (o.status == OrderStatus.delivered) {
        tallyOfDay.revenue += o.totalVnd;
        tallyOfDay.byKiosk.update(o.kioskId, (v) => v + o.totalVnd, ifAbsent: () => o.totalVnd);
      }
      if (o.status != OrderStatus.cancelled) hours[vietnam.hour]++;
    }
    final top = [
      for (final e in dishes.entries) DishSales(name: e.key, quantity: e.value.quantity, revenueVnd: e.value.revenue),
    ]..sort((a, b) => b.quantity != a.quantity ? b.quantity.compareTo(a.quantity) : a.name.compareTo(b.name));
    return SalesReport(
      orders: placed,
      delivered: delivered,
      cancelled: cancelled,
      active: active,
      revenueVnd: revenue,
      averagePrepSeconds: prep.isEmpty ? null : prep.reduce((a, b) => a + b) / prep.length,
      byDay: [
        for (final e in days.entries)
          DaySales(
            day: e.key,
            orders: e.value.orders,
            revenueVnd: e.value.revenue,
            revenueByKiosk: Map.unmodifiable(e.value.byKiosk),
          ),
      ]..sort((a, b) => a.day.compareTo(b.day)),
      byHour: List.unmodifiable(hours),
      byKiosk:
          [
            for (final e in kiosks.entries)
              KioskSales(
                kioskId: e.key,
                kioskName: e.value.name,
                orders: e.value.orders,
                delivered: e.value.delivered,
                cancelled: e.value.cancelled,
                revenueVnd: e.value.revenue,
              ),
          ]..sort(
            (a, b) => b.revenueVnd != a.revenueVnd
                ? b.revenueVnd.compareTo(a.revenueVnd)
                : a.kioskName.compareTo(b.kioskName),
          ),
      topDishes: top.take(topDishCount).toList(),
      truncated: truncated,
    );
  }

  final int orders;
  final int delivered;
  final int cancelled;
  final int active;
  final int revenueVnd;
  final double? averagePrepSeconds;
  final List<DaySales> byDay;

  /// Orders that were not cancelled, by hour of the day on the Vietnam clock (24 numbers, index = hour).
  final List<int> byHour;
  final List<KioskSales> byKiosk;
  final List<DishSales> topDishes;

  /// True when the period holds more orders than were read, so the figures are for the newest ones.
  final bool truncated;

  /// The part of the placed orders that were cancelled, 0 to 1.
  double get cancelRate => orders == 0 ? 0 : cancelled / orders;

  /// The average takings of a delivered order, or 0.
  int get averageOrderVnd => delivered == 0 ? 0 : (revenueVnd / delivered).round();

  /// The best day's takings, for scaling a bar chart.
  int get bestDayRevenueVnd => byDay.fold(0, (best, d) => d.revenueVnd > best ? d.revenueVnd : best);
}

class _DayTally {
  int orders = 0;
  int revenue = 0;
  final byKiosk = <String, int>{};
}

class _KioskTally {
  _KioskTally(this.name);

  final String name;
  int orders = 0;
  int delivered = 0;
  int cancelled = 0;
  int revenue = 0;
}
