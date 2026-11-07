import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/paged.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

enum HistoryGrouping { week, month }

/// The orders of one week or month, with how many there were and what was spent.
class HistoryGroup {
  const HistoryGroup({required this.id, required this.title, required this.summary, required this.orders});

  /// Stable key (`w20261102` for the week starting that Monday, `m202611` for a month), used for test ids.
  final String id;
  final String title;
  final String summary;
  final List<Order> orders;
}

/// S11: the customer's finished and cancelled orders, grouped by week or month, loaded a page at a time.
class OrderHistoryViewModel extends ChangeNotifier with SafeChangeNotifier {
  OrderHistoryViewModel({
    required this.orders,
    required this.crash,
    required this.uid,
    this.pageSize = Paged.defaultLimit,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    loadMore = Command0(_loadMore);
    unawaited(load());
  }

  static const emptyMessage = 'Chưa có đơn đã hoàn tất hoặc đã huỷ.';

  final OrderRepository orders;
  final CrashService crash;
  final String uid;
  final int pageSize;
  final DateTime Function() _clock;

  late final Command0<void> loadMore;

  ViewState<List<Order>> _state = const ViewLoading();
  PageCursor? _next;
  HistoryGrouping _grouping = HistoryGrouping.week;
  int _generation = 0;

  ViewState<List<Order>> get state => _state;
  HistoryGrouping get grouping => _grouping;

  /// More, older orders can be loaded.
  bool get hasMore => _next != null;

  static bool _isFinished(Order order) =>
      order.status == OrderStatus.delivered || order.status == OrderStatus.cancelled;

  void setGrouping(HistoryGrouping value) {
    if (value == _grouping) return;
    _grouping = value;
    notifyListeners();
  }

  /// Loads the first page. A page made only of orders still in progress is skipped, so the list is never
  /// empty while older finished orders exist.
  Future<void> load() async {
    final generation = ++_generation;
    _state = const ViewLoading();
    _next = null;
    notifyListeners();
    final loaded = <Order>[];
    PageCursor? cursor;
    do {
      final result = await orders.fetchMyOrders(uid, limit: pageSize, after: cursor);
      if (generation != _generation) return;
      switch (result) {
        case Ok(:final value):
          loaded.addAll(value.items.where(_isFinished));
          cursor = value.next;
        case Err(:final error):
          crash.recordNonFatal(error, error.stackTrace, 'orderHistory.load');
          _state = ViewError(error.message);
          notifyListeners();
          return;
      }
    } while (loaded.isEmpty && cursor != null);
    _next = cursor;
    _state = ViewStateX.fromList(loaded, emptyMessage: emptyMessage);
    notifyListeners();
  }

  Future<Result<void>> _loadMore() async {
    final cursor = _next;
    final current = _state.dataOrNull;
    if (cursor == null || current == null) return const Result.ok(null);
    final generation = _generation;
    final result = await orders.fetchMyOrders(uid, limit: pageSize, after: cursor);
    if (generation != _generation) return const Result.ok(null);
    switch (result) {
      case Ok(:final value):
        _state = ViewData([...current, ...value.items.where(_isFinished)]);
        _next = value.next;
        notifyListeners();
        return const Result.ok(null);
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'orderHistory.loadMore');
        return Result.error(error);
    }
  }

  /// The loaded orders in groups, newest group first.
  List<HistoryGroup> get groups {
    final all = [...?_state.dataOrNull]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final now = _clock();
    final byKey = <DateTime, List<Order>>{};
    for (final order in all) {
      final created = order.createdAt.toLocal();
      final key = _grouping == HistoryGrouping.week ? _weekStart(created) : DateTime(created.year, created.month);
      (byKey[key] ??= []).add(order);
    }
    return [
      for (final MapEntry(:key, :value) in byKey.entries)
        HistoryGroup(
          id: _grouping == HistoryGrouping.week ? 'w${_stamp(key)}' : 'm${key.year}${_two(key.month)}',
          title: _grouping == HistoryGrouping.week ? _weekTitle(key, now) : _monthTitle(key, now),
          summary: _summary(value),
          orders: value,
        ),
    ];
  }

  // ---- The spending card: what was spent this week or this month, by day of the week ----

  /// Mon to Sun, the labels of the bars.
  static const weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  /// "Chi tiêu tuần này" or "Chi tiêu tháng 11": the period follows the Tuần / Tháng tab and ends today.
  String get spendTitle => _grouping == HistoryGrouping.week ? 'Chi tiêu tuần này' : 'Chi tiêu tháng ${_clock().month}';

  /// Delivered orders of the loaded ones that were placed in the current week or month.
  Iterable<Order> get _spent {
    final now = _clock();
    final start = _grouping == HistoryGrouping.week ? _weekStart(now) : DateTime(now.year, now.month);
    final end = _grouping == HistoryGrouping.week
        ? DateTime(start.year, start.month, start.day + 7)
        : DateTime(now.year, now.month + 1);
    return [...?_state.dataOrNull].where((o) {
      final created = o.createdAt.toLocal();
      return o.status == OrderStatus.delivered && !created.isBefore(start) && created.isBefore(end);
    });
  }

  int get spendTotal => _spent.fold(0, (sum, o) => sum + o.totalVnd);

  /// What was spent on each day of the week (Monday first), added up over the period.
  List<int> get spendByWeekday {
    final days = List.filled(7, 0);
    for (final order in _spent) {
      days[order.createdAt.toLocal().weekday - 1] += order.totalVnd;
    }
    return days;
  }

  /// Index into [weekdayLabels] of the day with the most spending, `null` when nothing was spent.
  int? get peakWeekday {
    final most = mostSpentInADay;
    return most == 0 ? null : spendByWeekday.indexOf(most);
  }

  /// The highest bar of the chart (0 when nothing was spent); every bar is drawn relative to it.
  int get mostSpentInADay => spendByWeekday.fold(0, (a, b) => b > a ? b : a);

  /// One order's row: when it was placed and how it ended.
  String title(Order order) => '#${order.orderCode} · ${formatDayMonth(order.createdAt)}';

  String ending(Order order) => switch (order.status) {
    OrderStatus.delivered => 'Đã nhận lúc ${formatTime(order.deliveredAt ?? order.updatedAt ?? order.createdAt)}',
    _ => 'Đã huỷ',
  };

  static String _summary(List<Order> group) {
    final cancelled = group.where((o) => o.status == OrderStatus.cancelled).length;
    final spent = group.where((o) => o.status == OrderStatus.delivered).fold<int>(0, (sum, o) => sum + o.totalVnd);
    final cancelledNote = cancelled > 0 ? ' ($cancelled đã huỷ)' : '';
    return '${group.length} đơn$cancelledNote · đã chi ${formatVnd(spent)}';
  }

  /// Monday 00:00 of the week of [day].
  static DateTime _weekStart(DateTime day) => DateTime(day.year, day.month, day.day - (day.weekday - 1));

  static String _weekTitle(DateTime start, DateTime now) {
    final end = DateTime(start.year, start.month, start.day + 6);
    final range = '${formatDayMonth(start)} – ${formatDayMonth(end)}';
    final thisWeek = _weekStart(now);
    if (start == thisWeek) return 'Tuần này ($range)';
    if (start == DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7)) return 'Tuần trước ($range)';
    return 'Tuần $range';
  }

  static String _monthTitle(DateTime start, DateTime now) {
    final label = '${start.month}/${start.year}';
    if (start == DateTime(now.year, now.month)) return 'Tháng này ($label)';
    if (start == DateTime(now.year, now.month - 1)) return 'Tháng trước ($label)';
    return 'Tháng $label';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _stamp(DateTime day) => '${day.year}${_two(day.month)}${_two(day.day)}';

  @override
  void dispose() {
    _generation++;
    loadMore.dispose();
    super.dispose();
  }
}
