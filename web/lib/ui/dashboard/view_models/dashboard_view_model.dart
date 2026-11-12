import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/domain/models/kiosk_stats.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

enum DashboardPeriod { today, week }

/// W04 Dashboard: the kiosk's figures from Firestore aggregation queries (`count()`, `sum('totalVnd')`,
/// `average('prepSeconds')`, computed on the server by `OrderRepository.kioskStats`) and a chart of orders per
/// hour.
class DashboardViewModel extends ChangeNotifier with SafeChangeNotifier {
  DashboardViewModel({required this._orders, required this.kioskId, DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    load();
  }

  final OrderRepository _orders;
  final String kioskId;
  final DateTime Function() _now;

  DashboardPeriod _period = DashboardPeriod.today;
  ViewState<KioskStats> _state = const ViewLoading();
  int _loads = 0;

  DashboardPeriod get period => _period;
  ViewState<KioskStats> get state => _state;

  /// Midnight today, or midnight six days ago for the last seven days, in the browser's time zone.
  DateTime get since {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    return _period == DashboardPeriod.today ? today : today.subtract(const Duration(days: 6));
  }

  void setPeriod(DashboardPeriod value) {
    if (value == _period) return;
    _period = value;
    load();
  }

  Future<void> load() async {
    final load = ++_loads;
    _state = const ViewLoading();
    notifyListeners();
    final result = await _orders.kioskStats(kioskId, since: since);
    if (load != _loads) return; // a newer period was picked meanwhile
    _state = switch (result) {
      Ok(:final value) when value.deliveredCount + value.cancelledCount + value.activeCount == 0 => ViewEmpty(
        _period == DashboardPeriod.today ? 'Hôm nay kiosk chưa có đơn nào.' : '7 ngày qua kiosk chưa có đơn nào.',
      ),
      Ok(:final value) => ViewData(value),
      Err(:final error) => ViewError(error.message),
    };
    notifyListeners();
  }
}
