import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/seller_shop/view_models/shift_stats_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

/// Fails the next [failures] reads, then behaves like the fake.
class _FlakyOrders extends FakeOrderRepository {
  _FlakyOrders({this.failures = 0});

  int failures;
  final since = <DateTime>[];

  @override
  Future<Result<KioskStats>> kioskStats(String kioskId, {required DateTime since}) {
    this.since.add(since);
    if (failures > 0) {
      failures--;
      return Future.value(const Result.error(NetworkException()));
    }
    return super.kioskStats(kioskId, since: since);
  }
}

// "Now" is 12:00; the orders of the fake repository are placed from 9:01.
final _now = DateTime(2026, 11, 2, 12);

ShiftStatsViewModel _vm(
  FakeOrderRepository orders, {
  FakeMenuRepository? menu,
  String? kioskId = 'q9-t2',
  FakeCrashService? crash,
}) => ShiftStatsViewModel(
  orders: orders,
  menu: menu ?? FakeMenuRepository(),
  crash: crash ?? FakeCrashService(),
  kioskId: kioskId,
  clock: () => _now,
);

Future<void> _deliver(FakeOrderRepository orders, String id) async {
  Order current() => orders.all.firstWhere((o) => o.id == id);
  await orders.accept(current(), readyIn: const Duration(minutes: 5));
  await orders.markReady(current());
  await orders.deliver(current());
}

void main() {
  group('ShiftStatsViewModel', () {
    test('has the figures of the shift once it has loaded', () async {
      final orders = FakeOrderRepository();
      final a = await placeTestOrder(orders, uid: 'u1');
      final b = await placeTestOrder(orders, uid: 'u2');
      final c = await placeTestOrder(orders, uid: 'u3');
      await placeTestOrder(orders, uid: 'u4');
      await _deliver(orders, a);
      await _deliver(orders, b);
      await orders.reject(orders.all.firstWhere((o) => o.id == c), reason: 'Hết món');

      final vm = _vm(orders);
      expect(vm.state, isA<ViewLoading<KioskStats>>());
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<KioskStats>>());
      expect((vm.stats.deliveredCount, vm.stats.cancelledCount, vm.stats.activeCount), (2, 1, 1));
      expect(vm.revenueLabel, '78.000đ');
      expect(vm.averagePrepLabel, '1 phút');
      expect(vm.kioskName, 'Kiosk Q9 · Tầng 2');
      expect(vm.updatedLabel, 'Cập nhật lúc 12:00');
      expect(vm.refreshing, isFalse);
      vm.dispose();
    });

    test('says when the shift has no order yet', () async {
      final vm = _vm(FakeOrderRepository());
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<KioskStats>>());
      expect((vm.state as ViewEmpty).message, ShiftStatsViewModel.emptyMessage);
      expect(vm.averagePrepLabel, '—');
      expect(vm.bars, isEmpty);
      expect(vm.peakLabel, isNull);
      vm.dispose();
    });

    test('says so when the account has no kiosk, without reading anything', () async {
      final orders = _FlakyOrders();
      final vm = _vm(orders, kioskId: null);
      await pumpEventQueue();

      expect((vm.state as ViewEmpty).message, ShiftStatsViewModel.noKioskMessage);
      expect(vm.hasKiosk, isFalse);
      expect(orders.since, isEmpty);
      vm.dispose();
    });

    test('counts only the orders of the staff member\'s kiosk', () async {
      final orders = FakeOrderRepository();
      await placeTestOrder(orders, uid: 'u1');
      await placeTestOrder(orders, uid: 'u2', kioskId: 'q9-t4');
      final vm = _vm(orders);
      await pumpEventQueue();

      expect(vm.stats.totalCount, 1);
      vm.dispose();
    });

    group('the start of the shift', () {
      test('is the opening time of today, or midnight without one', () {
        expect(ShiftStatsViewModel.shiftStartOf(_now), DateTime(2026, 11, 2));
        expect(ShiftStatsViewModel.shiftStartOf(_now, openTime: '06:30'), DateTime(2026, 11, 2, 6, 30));
        expect(ShiftStatsViewModel.shiftStartOf(_now, openTime: '12:00'), DateTime(2026, 11, 2, 12));
      });

      test('is midnight when the kiosk opens later than it is now, or the time is not valid', () {
        expect(ShiftStatsViewModel.shiftStartOf(_now, openTime: '15:00'), DateTime(2026, 11, 2));
        expect(ShiftStatsViewModel.shiftStartOf(_now, openTime: '6:30'), DateTime(2026, 11, 2));
        expect(ShiftStatsViewModel.shiftStartOf(_now, openTime: 'sáng'), DateTime(2026, 11, 2));
      });

      test('is read from the kiosk and shown on the screen', () async {
        final menu = FakeMenuRepository();
        await menu.updateKiosk('q9-t2', const KioskSettings(open: true, waitMinutes: 6, openTime: '08:00'));
        final orders = _FlakyOrders();
        final vm = _vm(orders, menu: menu);
        await pumpEventQueue();

        expect(orders.since, [DateTime(2026, 11, 2, 8)]);
        expect(vm.shiftStart, DateTime(2026, 11, 2, 8));
        expect(vm.shiftLabel, 'Từ 08:00 hôm nay');
        vm.dispose();
      });
    });

    group('the chart', () {
      test('has a bar for every hour from the start of the shift to now, and names the busiest hour', () async {
        final menu = FakeMenuRepository();
        await menu.updateKiosk('q9-t2', const KioskSettings(open: true, waitMinutes: 6, openTime: '08:00'));
        final orders = FakeOrderRepository();
        for (var i = 0; i < 3; i++) {
          await placeTestOrder(orders, uid: 'u$i');
        }
        final vm = _vm(orders, menu: menu);
        await pumpEventQueue();

        expect(vm.bars.map((b) => b.hour), [8, 9, 10, 11, 12]);
        expect(vm.bars.map((b) => b.count), [0, 3, 0, 0, 0]);
        expect(vm.bars.first.label, '08');
        expect(vm.maxBarCount, 3);
        expect(vm.peakLabel, 'Cao điểm 09:00 · 3 đơn');
        vm.dispose();
      });

      test('is empty when every order was placed before the shift started', () async {
        final orders = FakeOrderRepository();
        await placeTestOrder(orders, uid: 'u1');
        final menu = FakeMenuRepository();
        await menu.updateKiosk('q9-t2', const KioskSettings(open: true, waitMinutes: 6, openTime: '10:00'));
        final vm = _vm(orders, menu: menu);
        await pumpEventQueue();

        // The only order was placed at 9:01, before the shift (10:00), so it is not counted or drawn.
        expect(vm.state, isA<ViewEmpty<KioskStats>>());
        expect(vm.bars, isEmpty);
        vm.dispose();
      });
    });

    group('refreshing', () {
      test('reads again and keeps the old figures on screen while it works', () async {
        final orders = _FlakyOrders();
        await placeTestOrder(orders, uid: 'u1');
        final vm = _vm(orders);
        await pumpEventQueue();
        expect(vm.stats.totalCount, 1);

        await placeTestOrder(orders, uid: 'u2');
        final refresh = vm.load();
        expect(vm.refreshing, isTrue);
        expect(vm.state, isA<ViewData<KioskStats>>());
        await refresh;

        expect((vm.stats.totalCount, vm.refreshing), (2, false));
        expect(vm.takeRefreshError(), isNull);
        vm.dispose();
      });

      test('ignores a second refresh while one is running', () async {
        final orders = _FlakyOrders();
        await placeTestOrder(orders, uid: 'u1');
        final vm = _vm(orders);
        await pumpEventQueue();
        orders.since.clear();

        final first = vm.load();
        final second = vm.load();
        await Future.wait([first, second]);

        expect(orders.since, hasLength(1));
        vm.dispose();
      });

      test('keeps the old figures and reports the error when a refresh fails', () async {
        final crash = FakeCrashService();
        final orders = _FlakyOrders();
        await placeTestOrder(orders, uid: 'u1');
        final vm = _vm(orders, crash: crash);
        await pumpEventQueue();

        orders.failures = 1;
        await vm.load();

        expect(vm.state, isA<ViewData<KioskStats>>());
        expect(vm.stats.totalCount, 1);
        expect(vm.takeRefreshError(), isNotNull);
        expect(vm.takeRefreshError(), isNull);
        expect(crash.errors, hasLength(1));
        vm.dispose();
      });
    });

    test('shows an error when the first read fails, and retries', () async {
      final orders = _FlakyOrders(failures: 1);
      await placeTestOrder(orders, uid: 'u1');
      final vm = _vm(orders);
      await pumpEventQueue();

      expect(vm.state, isA<ViewError<KioskStats>>());

      await vm.load();
      expect(vm.state, isA<ViewData<KioskStats>>());
      expect(vm.stats.totalCount, 1);
      vm.dispose();
    });
  });

  group('prepTimeLabel', () {
    test('writes seconds and minutes the way staff say them', () {
      expect(prepTimeLabel(null), '—');
      expect(prepTimeLabel(0), '0 giây');
      expect(prepTimeLabel(45.4), '45 giây');
      expect(prepTimeLabel(60), '1 phút');
      expect(prepTimeLabel(200), '3 phút 20 giây');
      expect(prepTimeLabel(179.6), '3 phút');
    });
  });
}
