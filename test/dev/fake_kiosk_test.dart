import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fakes/fakes.dart';
import '../helpers/orders.dart';

Future<Kiosk> _kiosk(FakeMenuRepository menu, String id) async =>
    (await menu.watchKiosks().first).firstWhere((k) => k.id == id);

Future<void> _deliver(FakeOrderRepository orders, String id) async {
  var order = orders.all.firstWhere((o) => o.id == id);
  await orders.accept(order, readyIn: const Duration(minutes: 5));
  order = orders.all.firstWhere((o) => o.id == id);
  await orders.markReady(order);
  order = orders.all.firstWhere((o) => o.id == id);
  await orders.deliver(order);
}

void main() {
  group('FakeMenuRepository.updateKiosk', () {
    test('writes the settings as a whole and removes the fields that are empty', () async {
      final menu = FakeMenuRepository();
      final until = DateTime(2026, 11, 2, 10);
      final first = KioskSettings(
        open: true,
        waitMinutes: 9,
        pausedUntil: until,
        maxOrdersPerSlot: 4,
        notice: '  Hết sốt  ',
        openTime: '06:30',
        closeTime: '17:00',
      );

      expect((await menu.updateKiosk('q9-t2', first)).isOk, isTrue);
      var kiosk = await _kiosk(menu, 'q9-t2');
      expect((kiosk.waitMinutes, kiosk.maxOrdersPerSlot, kiosk.notice), (9, 4, 'Hết sốt'));
      expect((kiosk.openTime, kiosk.closeTime, kiosk.pausedUntil), ('06:30', '17:00', until));

      await menu.updateKiosk('q9-t2', const KioskSettings(open: false, waitMinutes: 0));
      kiosk = await _kiosk(menu, 'q9-t2');
      expect(kiosk.open, isFalse);
      expect((kiosk.notice, kiosk.openTime, kiosk.pausedUntil, kiosk.maxOrdersPerSlot), (null, null, null, null));
      expect(kiosk.name, 'Kiosk Q9 · Tầng 2');
    });

    test('leaves the other kiosks alone', () async {
      final menu = FakeMenuRepository();
      await menu.updateKiosk('q9-t2', const KioskSettings(open: false, waitMinutes: 20));

      final other = await _kiosk(menu, 'q9-t4');
      expect((other.open, other.waitMinutes), (true, 10));
    });

    test('rejects settings the rules would reject, and a kiosk that does not exist', () async {
      final menu = FakeMenuRepository();

      final invalid = await menu.updateKiosk('q9-t2', const KioskSettings(open: true, waitMinutes: 121));
      expect((invalid as Err<void>).error, isA<ValidationException>());
      expect((await menu.updateKiosk('nope', const KioskSettings(open: true, waitMinutes: 5))).isOk, isFalse);
      expect((await _kiosk(menu, 'q9-t2')).waitMinutes, 6);
    });

    test('a customer\'s kiosk list follows the change', () async {
      final menu = FakeMenuRepository();
      final seen = menu.watchKiosks().map((l) => l.firstWhere((k) => k.id == 'q9-t2').open).take(2).toList();

      await pumpEventQueue();
      await menu.updateKiosk('q9-t2', const KioskSettings(open: false, waitMinutes: 6));

      expect(await seen, [true, false]);
    });
  });

  group('FakeOrderRepository.kioskStats', () {
    test('counts the orders of one kiosk by outcome and times the preparation', () async {
      final orders = FakeOrderRepository();
      final a = await placeTestOrder(orders, uid: 'u1');
      final b = await placeTestOrder(
        orders,
        uid: 'u2',
        items: const [CartItem(itemId: 'm2', name: 'Mì', priceVnd: 35000)],
      );
      await placeTestOrder(orders, uid: 'u3');
      final d = await placeTestOrder(orders, uid: 'u4');
      await placeTestOrder(orders, uid: 'u5', kioskId: 'q9-t4');
      await _deliver(orders, a);
      await _deliver(orders, b);
      await orders.reject(orders.all.firstWhere((o) => o.id == d), reason: 'Hết món');

      final stats = (await orders.kioskStats('q9-t2', since: DateTime(2026, 11, 2)) as Ok<KioskStats>).value;

      expect((stats.deliveredCount, stats.revenueVnd), (2, 39000 + 35000));
      expect((stats.cancelledCount, stats.activeCount), (1, 1));
      // The fake clock moves a minute per step, so accepting then marking ready takes 60 s.
      expect(stats.averagePrepSeconds, 60);
      expect(stats.ordersByHour.values.fold(0, (s, n) => s + n), 3);
    });

    test('leaves out the orders placed before the shift started', () async {
      final orders = FakeOrderRepository();
      await placeTestOrder(orders, uid: 'u1');
      final placedAt = orders.all.single.createdAt;

      final before = await orders.kioskStats('q9-t2', since: placedAt.add(const Duration(minutes: 1)));
      final at = await orders.kioskStats('q9-t2', since: placedAt);

      expect((before as Ok<KioskStats>).value.totalCount, 0);
      expect((at as Ok<KioskStats>).value.totalCount, 1);
    });
  });
}
