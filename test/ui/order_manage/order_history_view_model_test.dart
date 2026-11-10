import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/order_manage/view_models/order_history_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/order_history.dart';

// "Now" is Wednesday 4 November 2026; this week started on Monday 2 November.
final _now = DateTime(2026, 11, 4, 10);

const _order = historyOrder;

final _active = _order('act', DateTime(2026, 11, 4, 9), status: OrderStatus.pending);
final _thisWeek = _order('o1', DateTime(2026, 11, 3, 12), deliveredAt: DateTime(2026, 11, 3, 12, 30));
final _thisWeekCancelled = _order('o2', DateTime(2026, 11, 2, 8), status: OrderStatus.cancelled, total: 20000);
final _lastWeekThursday = _order('o3', DateTime(2026, 10, 29, 12), total: 50000);
final _lastWeekTuesday = _order('o4', DateTime(2026, 10, 27, 12), total: 30000);
final _october5 = _order('o5', DateTime(2026, 10, 5, 12), total: 45000);
final _september = _order('o6', DateTime(2026, 9, 15, 12), total: 60000);

/// Newest first, as the repository returns them.
final _all = [_active, _thisWeek, _thisWeekCancelled, _lastWeekThursday, _lastWeekTuesday, _october5, _september];

OrderHistoryViewModel _vm(OrderRepository orders, {int pageSize = 20, FakeCrashService? crash}) =>
    OrderHistoryViewModel(
      orders: orders,
      crash: crash ?? FakeCrashService(),
      uid: 'u1',
      pageSize: pageSize,
      clock: () => _now,
    );

List<String> _ids(Iterable<Order> orders) => orders.map((o) => o.id).toList();

void main() {
  group('OrderHistoryViewModel spending card', () {
    // Today is Wednesday 4 November. Spent this week: 20.000 + 30.000 on Monday and 10.000 today; Sunday 1 November
    // is in the month but not in the week; a cancelled order and one from October count in neither.
    final spending = [
      _order('a', DateTime(2026, 11, 2, 9), total: 20000),
      _order('b', DateTime(2026, 11, 2, 12), total: 30000),
      _order('c', DateTime(2026, 11, 4, 9), total: 10000),
      _order('d', DateTime(2026, 11, 1, 12), total: 40000),
      _order('e', DateTime(2026, 11, 3, 12), status: OrderStatus.cancelled, total: 99000),
      _order('f', DateTime(2026, 10, 30, 12), total: 70000),
    ];

    test('this week: the title, the total and what was spent on each day, Monday first', () async {
      final vm = _vm(PagedOrders(spending));
      await pumpEventQueue();

      expect(vm.spendTitle, 'Chi tiêu tuần này');
      expect(vm.spendTotal, 60000);
      expect(vm.spendByWeekday, [50000, 0, 10000, 0, 0, 0, 0]);
      expect(vm.peakWeekday, 0);
      expect(vm.mostSpentInADay, 50000);
      expect(OrderHistoryViewModel.weekdayLabels[vm.peakWeekday!], 'T2');
      vm.dispose();
    });

    test('this month: follows the Tháng tab and adds the Sunday that is in November but not in this week', () async {
      final vm = _vm(PagedOrders(spending));
      await pumpEventQueue();

      vm.setGrouping(HistoryGrouping.month);

      expect(vm.spendTitle, 'Chi tiêu tháng 11');
      expect(vm.spendTotal, 100000);
      expect(vm.spendByWeekday, [50000, 0, 10000, 0, 0, 0, 40000]);
      vm.dispose();
    });

    test('with nothing spent in the period the total is 0 and no day is the busiest', () async {
      final vm = _vm(PagedOrders([_order('f', DateTime(2026, 10, 30, 12))]));
      await pumpEventQueue();

      expect(vm.spendTotal, 0);
      expect(vm.spendByWeekday, List.filled(7, 0));
      expect(vm.peakWeekday, isNull);
      expect(vm.mostSpentInADay, 0);
      vm.dispose();
    });
  });

  group('OrderHistoryViewModel', () {
    test('by week: orders in progress are left out and each week says how many and what was spent', () async {
      final vm = _vm(PagedOrders(_all));
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<List<Order>>>());
      expect(vm.grouping, HistoryGrouping.week);
      expect(vm.groups.map((g) => (g.id, g.title, g.summary)), [
        ('w20261102', 'Tuần này (02/11 – 08/11)', '2 đơn (1 đã huỷ) · đã chi 39.000đ'),
        ('w20261026', 'Tuần trước (26/10 – 01/11)', '2 đơn · đã chi 80.000đ'),
        ('w20261005', 'Tuần 05/10 – 11/10', '1 đơn · đã chi 45.000đ'),
        ('w20260914', 'Tuần 14/09 – 20/09', '1 đơn · đã chi 60.000đ'),
      ]);
      expect(_ids(vm.groups[0].orders), ['o1', 'o2']);
      expect(_ids(vm.groups[1].orders), ['o3', 'o4']);
      expect(vm.groups.expand((g) => g.orders).map((o) => o.id), isNot(contains('act')));
      vm.dispose();
    });

    test('by month: the same orders gather into months', () async {
      final vm = _vm(PagedOrders(_all));
      await pumpEventQueue();
      vm.setGrouping(HistoryGrouping.month);

      expect(vm.groups.map((g) => (g.id, g.title, g.summary)), [
        ('m202611', 'Tháng này (11/2026)', '2 đơn (1 đã huỷ) · đã chi 39.000đ'),
        ('m202610', 'Tháng trước (10/2026)', '3 đơn · đã chi 125.000đ'),
        ('m202609', 'Tháng 9/2026', '1 đơn · đã chi 60.000đ'),
      ]);
      vm.dispose();
    });

    test('switching between week and month tells the screen, and choosing the same one does not', () async {
      final vm = _vm(PagedOrders(_all));
      await pumpEventQueue();
      var notified = 0;
      vm.addListener(() => notified++);

      vm.setGrouping(HistoryGrouping.month);
      vm.setGrouping(HistoryGrouping.month);
      vm.setGrouping(HistoryGrouping.week);
      expect(notified, 2);
      expect(vm.grouping, HistoryGrouping.week);
      vm.dispose();
    });

    test('a week that crosses a month still counts as one week', () async {
      final vm = _vm(PagedOrders([_order('a', DateTime(2026, 11, 1, 9)), _order('b', DateTime(2026, 10, 31, 9))]));
      await pumpEventQueue();

      expect(vm.groups.map((g) => g.title), ['Tuần trước (26/10 – 01/11)']);
      expect(_ids(vm.groups.single.orders), ['a', 'b']);
      vm.dispose();
    });

    test('a row says when the order was placed and how it ended', () async {
      final vm = _vm(PagedOrders(_all));
      await pumpEventQueue();

      expect(vm.title(_thisWeek), '#O1 · 03/11');
      expect(vm.ending(_thisWeek), 'Đã nhận lúc 12:30');
      expect(vm.ending(_thisWeekCancelled), 'Đã huỷ');
      vm.dispose();
    });

    test('older orders load a page at a time until none are left', () async {
      final repo = PagedOrders(_all);
      final vm = _vm(repo, pageSize: 2);
      await pumpEventQueue();

      expect(_ids(vm.groups.expand((g) => g.orders)), ['o1']);
      expect(vm.hasMore, isTrue);

      final first = await vm.loadMore.execute();
      expect(first, isA<Ok<void>>());
      expect(_ids(vm.groups.expand((g) => g.orders)), ['o1', 'o2', 'o3']);
      expect(vm.hasMore, isTrue);

      await vm.loadMore.execute();
      await vm.loadMore.execute();
      expect(_ids(vm.groups.expand((g) => g.orders)), ['o1', 'o2', 'o3', 'o4', 'o5', 'o6']);
      expect(vm.hasMore, isFalse);

      final calls = repo.calls;
      await vm.loadMore.execute();
      expect(repo.calls, calls, reason: 'nothing is fetched when there is no next page');
      vm.dispose();
    });

    test(
      '[CR-05] "older orders" skips a page made only of orders in progress and shows the next finished ones',
      () async {
        final repo = PagedOrders([
          _thisWeek,
          _thisWeekCancelled,
          _order('act2', DateTime(2026, 11, 1, 9), status: OrderStatus.pending),
          _order('act3', DateTime(2026, 10, 31, 9), status: OrderStatus.preparing),
          _lastWeekThursday,
        ]);
        final vm = _vm(repo, pageSize: 2);
        await pumpEventQueue();
        expect(_ids(vm.groups.expand((g) => g.orders)), ['o1', 'o2']);

        final result = await vm.loadMore.execute();

        expect(result, isA<Ok<void>>());
        expect(_ids(vm.groups.expand((g) => g.orders)), ['o1', 'o2', 'o3']);
        expect(vm.hasMore, isFalse);
        vm.dispose();
      },
    );

    test('a first page made only of orders in progress keeps loading until a finished order shows up', () async {
      final repo = PagedOrders([
        _active,
        _order('act2', DateTime(2026, 11, 4, 9, 30), status: OrderStatus.preparing),
        _thisWeek,
        _thisWeekCancelled,
      ]);
      final vm = _vm(repo, pageSize: 2);
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<List<Order>>>());
      expect(_ids(vm.groups.expand((g) => g.orders)), ['o1', 'o2']);
      expect(repo.calls, 2);
      vm.dispose();
    });

    test('with only orders in progress, or none at all, it is the empty state', () async {
      final onlyActive = _vm(PagedOrders([_active]));
      final none = _vm(PagedOrders(const []));
      await pumpEventQueue();

      for (final vm in [onlyActive, none]) {
        expect(vm.state, isA<ViewEmpty<List<Order>>>());
        expect((vm.state as ViewEmpty<List<Order>>).message, OrderHistoryViewModel.emptyMessage);
        expect(vm.hasMore, isFalse);
        expect(vm.groups, isEmpty);
        vm.dispose();
      }
    });

    test('a failed first load is an error with the reason, it is recorded, and retry loads again', () async {
      final repo = PagedOrders(_all)..failNext = const NetworkException();
      final crash = FakeCrashService();
      final vm = _vm(repo, crash: crash);
      await pumpEventQueue();

      expect(vm.state, isA<ViewError<List<Order>>>());
      expect((vm.state as ViewError<List<Order>>).message, const NetworkException().message);
      expect(crash.errors, hasLength(1));

      final retry = vm.load();
      expect(vm.state, isA<ViewLoading<List<Order>>>());
      await retry;
      expect(vm.state, isA<ViewData<List<Order>>>());
      vm.dispose();
    });

    test('a failed "older orders" keeps the list, reports the error and can be tried again', () async {
      final repo = PagedOrders(_all);
      final crash = FakeCrashService();
      final vm = _vm(repo, pageSize: 2, crash: crash);
      await pumpEventQueue();

      repo.failNext = const NetworkException();
      final failed = await vm.loadMore.execute();
      expect((failed! as Err<void>).error.message, const NetworkException().message);
      expect(_ids(vm.groups.expand((g) => g.orders)), ['o1']);
      expect(vm.hasMore, isTrue);
      expect(crash.errors, hasLength(1));

      final again = await vm.loadMore.execute();
      expect(again, isA<Ok<void>>());
      expect(_ids(vm.groups.expand((g) => g.orders)), ['o1', 'o2', 'o3']);
      vm.dispose();
    });

    test('an answer that arrives after a reload is ignored', () async {
      final repo = PagedOrders(_all);
      final vm = _vm(repo, pageSize: 2);
      await pumpEventQueue();
      final stale = vm.loadMore.execute();
      final reload = vm.load();
      await Future.wait([stale, reload]);

      expect(_ids(vm.groups.expand((g) => g.orders)), ['o1']);
      expect(vm.hasMore, isTrue);
      vm.dispose();
    });
  });
}
