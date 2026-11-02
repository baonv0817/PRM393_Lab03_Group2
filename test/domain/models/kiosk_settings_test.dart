import 'package:breakbite/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Order _order(String id, OrderStatus status, {int total = 40000, int hour = 9, int? prepSeconds}) => Order(
  id: id,
  uid: 'u',
  items: const [],
  totalVnd: total,
  paymentMethod: PaymentMethod.momo,
  status: status,
  kioskId: 'q9-t2',
  createdAt: DateTime(2026, 11, 2, hour, 15),
  prepSeconds: prepSeconds,
);

void main() {
  group('KioskSettings', () {
    const base = KioskSettings(open: true, waitMinutes: 6);

    test('copies the kiosk it describes', () {
      final kiosk = Kiosk(
        id: 'q9-t2',
        name: 'Q9',
        open: false,
        waitMinutes: 3,
        notice: 'Hết sốt',
        openTime: '06:30',
        closeTime: '17:00',
        pausedUntil: DateTime(2026, 11, 2, 10),
        maxOrdersPerSlot: 5,
      );
      final settings = KioskSettings.of(kiosk);

      expect((settings.open, settings.waitMinutes, settings.notice), (false, 3, 'Hết sốt'));
      expect((settings.openTime, settings.closeTime, settings.maxOrdersPerSlot), ('06:30', '17:00', 5));
      expect(settings.pausedUntil, DateTime(2026, 11, 2, 10));
    });

    test('copyWith keeps a field that is not given and clears one that is given as null', () {
      final full = base.copyWith(notice: 'Hết sốt', maxOrdersPerSlot: 5, pausedUntil: DateTime(2026, 11, 2, 10));

      final kept = full.copyWith(waitMinutes: 8);
      expect((kept.notice, kept.maxOrdersPerSlot, kept.pausedUntil), ('Hết sốt', 5, DateTime(2026, 11, 2, 10)));

      final cleared = full.copyWith(notice: null, maxOrdersPerSlot: null, pausedUntil: null);
      expect(cleared.notice, isNull);
      expect(cleared.maxOrdersPerSlot, isNull);
      expect(cleared.pausedUntil, isNull);
      expect(cleared.waitMinutes, 6);
    });

    test('accepts hours as HH:mm only', () {
      expect(['06:30', '00:00', '23:59'].every(KioskSettings.isClockTime), isTrue);
      expect(['6:30', '24:00', '12:60', '12-30', '', '12:3'].any(KioskSettings.isClockTime), isFalse);
    });

    test('says why settings cannot be saved', () {
      expect(base.problem, isNull);
      expect(base.copyWith(waitMinutes: 0).problem, isNull);
      expect(base.copyWith(waitMinutes: KioskSettings.maxWaitMinutes).problem, isNull);
      expect(base.copyWith(waitMinutes: -1).problem, contains('0 đến'));
      expect(base.copyWith(waitMinutes: KioskSettings.maxWaitMinutes + 1).problem, contains('0 đến'));
      expect(base.copyWith(maxOrdersPerSlot: 0).problem, contains('lớn hơn 0'));
      expect(base.copyWith(notice: 'x' * (KioskSettings.maxNoticeLength + 1)).problem, contains('ký tự'));
      expect(base.copyWith(openTime: '6:30').problem, contains('06:30'));
      expect(base.copyWith(closeTime: '25:00').problem, contains('06:30'));
      expect(base.copyWith(openTime: '06:30', closeTime: '17:00').problem, isNull);
    });
  });

  group('KioskStats', () {
    test('counts what was sold, cancelled and still open, and averages the preparation time', () {
      final stats = KioskStats.fromOrders([
        _order('a', OrderStatus.delivered, total: 40000, prepSeconds: 120),
        _order('b', OrderStatus.delivered, total: 25000, prepSeconds: 240),
        _order('c', OrderStatus.delivered, total: 10000),
        _order('d', OrderStatus.cancelled, total: 99000),
        _order('e', OrderStatus.pending),
        _order('f', OrderStatus.preparing),
        _order('g', OrderStatus.ready),
      ]);

      expect((stats.deliveredCount, stats.revenueVnd), (3, 75000));
      expect((stats.cancelledCount, stats.activeCount, stats.totalCount), (1, 3, 7));
      // An order without a measured time does not pull the average down.
      expect(stats.averagePrepSeconds, 180);
    });

    test('has no average when no delivered order was timed', () {
      expect(KioskStats.fromOrders([_order('a', OrderStatus.delivered)]).averagePrepSeconds, isNull);
      expect(KioskStats.fromOrders(const []).totalCount, 0);
      expect(KioskStats.empty.averagePrepSeconds, isNull);
    });

    test('draws the chart from orders that were not cancelled, and names the busiest hour', () {
      final stats = KioskStats.fromOrders([
        _order('a', OrderStatus.delivered, hour: 9),
        _order('b', OrderStatus.delivered, hour: 9),
        _order('c', OrderStatus.pending, hour: 11),
        _order('d', OrderStatus.cancelled, hour: 11),
        _order('e', OrderStatus.cancelled, hour: 11),
        _order('f', OrderStatus.delivered, hour: 12),
      ]);

      expect(stats.ordersByHour, {9: 2, 11: 1, 12: 1});
      expect(stats.peakHour, 9);
    });

    test('names the earlier hour when two hours are equally busy', () {
      final stats = KioskStats.fromOrders([
        _order('a', OrderStatus.delivered, hour: 12),
        _order('b', OrderStatus.delivered, hour: 8),
      ]);

      expect(stats.peakHour, 8);
      expect(KioskStats.empty.peakHour, isNull);
    });
  });
}
