import 'dart:async';
import 'dart:math';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// One bar of the hourly chart.
class HourBar {
  const HourBar({required this.hour, required this.count});

  final int hour;
  final int count;

  String get label => '${hour}h';
}

/// K11: what the kiosk did today, from the start of the shift: revenue, orders by outcome, the average
/// preparation time and the orders per hour. The figures are read when the screen opens and when the staff
/// member refreshes it, not live: a count that changes under the eyes is harder to read than a stale one that
/// says when it was taken.
class ShiftStatsViewModel extends ChangeNotifier with SafeChangeNotifier {
  ShiftStatsViewModel({
    required this.orders,
    required this.menu,
    required this.crash,
    required this.kioskId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    load();
  }

  static const noKioskMessage =
      'Tài khoản này chưa được gán kiosk nên chưa có thống kê. Nhờ quản trị viên gán kiosk cho bạn.';
  static const emptyMessage = 'Chưa có đơn nào trong ca này.';

  final OrderRepository orders;
  final MenuRepository menu;
  final CrashService crash;
  final String? kioskId;
  final DateTime Function() _clock;

  ViewState<KioskStats> _state = const ViewLoading();
  bool _refreshing = false;
  DateTime _shiftStart = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _updatedAt;
  String _kioskName = '';
  String? _lastError;

  ViewState<KioskStats> get state => _state;

  /// A refresh is running while the previous figures stay on screen.
  bool get refreshing => _refreshing;

  DateTime get shiftStart => _shiftStart;
  DateTime? get updatedAt => _updatedAt;
  String get kioskName => _kioskName;

  KioskStats get stats => _state.dataOrNull ?? KioskStats.empty;

  bool get hasKiosk => kioskId != null && kioskId!.isNotEmpty;

  Future<void> load() async {
    final id = kioskId;
    if (id == null || id.isEmpty) {
      _state = const ViewEmpty(noKioskMessage);
      notifyListeners();
      return;
    }
    if (_refreshing) return;
    final firstTime = _state is! ViewData<KioskStats>;
    if (firstTime) _state = const ViewLoading();
    _refreshing = true;
    notifyListeners();
    try {
      final now = _clock();
      final kiosk = await _kiosk(id);
      _kioskName = kiosk?.name ?? _kioskName;
      _shiftStart = shiftStartOf(now, openTime: kiosk?.openTime);
      switch (await orders.kioskStats(id, since: _shiftStart)) {
        case Ok(:final value):
          _updatedAt = now;
          _state = value.totalCount == 0 ? const ViewEmpty(emptyMessage) : ViewData(value);
        case Err(:final error):
          crash.recordNonFatal(error, error.stackTrace, 'shiftStats.kioskStats');
          // Keep the old figures when a refresh fails; the screen shows the error as a message.
          if (firstTime) _state = ViewError(error.message);
          _lastError = error.message;
      }
    } on Object catch (error, stack) {
      crash.recordNonFatal(error, stack, 'shiftStats.load');
      final message = error is AppException ? error.message : 'Không tải được thống kê.';
      if (firstTime) _state = ViewError(message);
      _lastError = message;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Why the last refresh failed while older figures are still shown, `null` when it worked.
  String? takeRefreshError() {
    final error = _lastError;
    _lastError = null;
    return error;
  }

  Future<Kiosk?> _kiosk(String id) async {
    try {
      final kiosks = await menu.watchKiosks().first;
      return kiosks.where((k) => k.id == id).firstOrNull;
    } on Object {
      // The hours only decide where the shift starts; without them it starts at midnight.
      return null;
    }
  }

  /// Today at [openTime], or at midnight when the kiosk has none or opens later than it is now.
  static DateTime shiftStartOf(DateTime now, {String? openTime}) {
    final midnight = DateTime(now.year, now.month, now.day);
    if (openTime == null || !KioskSettings.isClockTime(openTime)) return midnight;
    final parts = openTime.split(':');
    final start = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    return start.isAfter(now) ? midnight : start;
  }

  // ---- What the screen shows ----

  String get shiftLabel => 'Từ ${formatTime(_shiftStart)} hôm nay';

  String get updatedLabel => _updatedAt == null ? '' : 'Cập nhật lúc ${formatTime(_updatedAt!)}';

  String get revenueLabel => formatVnd(stats.revenueVnd);

  String get averagePrepLabel => prepTimeLabel(stats.averagePrepSeconds);

  /// Bars from the hour the shift started to the current hour (or the last hour with an order).
  List<HourBar> get bars {
    final byHour = stats.ordersByHour;
    if (byHour.isEmpty) return const [];
    final first = min(_shiftStart.hour, byHour.keys.reduce(min));
    final last = max(_clock().hour, byHour.keys.reduce(max));
    return [for (var h = first; h <= last; h++) HourBar(hour: h, count: byHour[h] ?? 0)];
  }

  int get maxBarCount => bars.fold(0, (m, b) => max(m, b.count));

  /// "Cao điểm 09:00 · 7 đơn", or `null` when nothing was ordered.
  String? get peakLabel {
    final hour = stats.peakHour;
    if (hour == null) return null;
    return 'Cao điểm ${hour.toString().padLeft(2, '0')}:00 · ${stats.ordersByHour[hour]} đơn';
  }

  static const truncatedNote = 'Biểu đồ chỉ tính 500 đơn mới nhất của ca; các con số phía trên vẫn đủ.';
}
