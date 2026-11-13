import 'dart:async';

import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/data/services/analytics_events.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/data/services/remote_config_service.dart';
import 'package:breakbite_core/data/services/stats_insight_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/domain/stats_digest.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// A08: takings and orders over a period, for every kiosk or one. The figures are worked out from the orders of the
/// period (`SalesReport`), up to [AdminOrderRepository.maxRange] of them, newest first; the page says when a
/// period holds more.
class AdminStatsViewModel extends ChangeNotifier with SafeChangeNotifier {
  AdminStatsViewModel({
    required this.orders,
    required this.menu,
    this.insightService,
    this.remoteConfig,
    this.analytics,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _kioskSub = menu.watchKiosks().listen((list) {
      _kiosks = list;
      notifyListeners();
    }, onError: (Object e, StackTrace s) {});
    load();
  }

  static const emptyMessage = 'Chưa có đơn nào trong khoảng thời gian này.';

  /// The periods offered, in days counted back from today (today included).
  static const periods = [7, 14, 30];

  final AdminOrderRepository orders;
  final MenuRepository menu;

  /// The AI summary (docs/ai-feature.md, "Stats summary"); all three are `null` in a build without it.
  final StatsInsightService? insightService;
  final RemoteConfigService? remoteConfig;
  final AnalyticsService? analytics;
  final DateTime Function() _clock;

  StreamSubscription<List<Kiosk>>? _kioskSub;
  List<Kiosk> _kiosks = const [];
  ViewState<SalesReport> _state = const ViewLoading();
  SalesReport? _previous;
  int _days = 7;
  String? _kioskId;
  int _generation = 0;
  ViewState<String>? _insight;
  int _insightGeneration = 0;

  static const insightFeature = 'stats_insight';

  /// The summary card is offered when the service exists and `ai_enabled` is on in Remote Config.
  bool get insightAvailable => insightService != null && (remoteConfig?.getBool(RemoteKeys.aiEnabled) ?? false);

  /// `null` until the admin asks; then loading, the text, or the reason it failed. Cleared when the figures change,
  /// because the text describes one period and kiosk.
  ViewState<String>? get insight => _insight;

  /// Asks Gemini to sum up the figures on screen. One request at a time; a failure leaves the charts untouched.
  Future<void> generateInsight() async {
    final service = insightService;
    final config = remoteConfig;
    if (_insight is ViewLoading) return;
    if (service == null || config == null || !insightAvailable) {
      _insight = ViewError(AiException.insight(AiFailure.disabled).message);
      notifyListeners();
      return;
    }
    final report = switch (_state) {
      ViewData<SalesReport>(:final data) => data,
      _ => null,
    };
    if (report == null) return;
    final generation = ++_insightGeneration;
    final model = config.getString(RemoteKeys.aiModel);
    _insight = const ViewLoading();
    notifyListeners();
    unawaited(analytics?.logEvent(AnalyticsEvents.aiRequest, {'feature': insightFeature, 'model': model}));
    final result = await service.summarize(
      statsDigest(
        report: report,
        previous: _previous,
        days: _days,
        kioskName: _kioskId == null ? null : kioskName(_kioskId!),
      ),
      model: model,
      prompt: config.getString(RemoteKeys.aiInsightPrompt),
    );
    if (generation != _insightGeneration) return;
    switch (result) {
      case Ok(:final value):
        _insight = ViewData(value);
      case Err(:final error):
        final reason = error is AiException ? error.reason : AiFailure.other;
        unawaited(
          analytics?.logEvent(AnalyticsEvents.aiError, {
            'feature': insightFeature,
            'reason': reason.analyticsName,
            'model': model,
          }),
        );
        _insight = ViewError(error.message);
    }
    notifyListeners();
  }

  DateTime get now => _clock();
  ViewState<SalesReport> get state => _state;

  /// The same figures for the period just before this one (same length, same kiosk), or `null` while it is not
  /// known or had no orders. The page shows the change against it.
  SalesReport? get previous => _previous;
  List<Kiosk> get kiosks => _kiosks;
  int get days => _days;

  String kioskName(String id) => _kiosks.where((k) => k.id == id).firstOrNull?.name ?? id;
  String? get kioskId => _kioskId;

  /// The period: from 00:00 of the first day to the end of today, on the Vietnam clock.
  ({DateTime from, DateTime to}) get period {
    final vietnam = now.toUtc().add(SlotPlan.vietnamOffset);
    final today = DateTime.utc(vietnam.year, vietnam.month, vietnam.day).subtract(SlotPlan.vietnamOffset);
    return (from: today.subtract(Duration(days: _days - 1)), to: today.add(const Duration(days: 1)));
  }

  Future<void> load() async {
    final generation = ++_generation;
    _insightGeneration++;
    _insight = null;
    _state = const ViewLoading();
    _previous = null;
    notifyListeners();
    final range = period;
    final span = Duration(days: _days);
    final results = await Future.wait([
      orders.fetchRange(from: range.from, to: range.to, kioskId: _kioskId),
      orders.fetchRange(from: range.from.subtract(span), to: range.from, kioskId: _kioskId),
    ]);
    if (generation != _generation) return;
    final result = results[0];
    // The comparison is a bonus: when it cannot be read the figures still show, without the change.
    if (results[1] case Ok(:final value) when value.isNotEmpty) {
      _previous = SalesReport.fromOrders(value, truncated: value.length >= AdminOrderRepository.maxRange);
    }
    switch (result) {
      case Ok<List<Order>>(:final value):
        _state = value.isEmpty
            ? const ViewEmpty(emptyMessage)
            : ViewData(SalesReport.fromOrders(value, truncated: value.length >= AdminOrderRepository.maxRange));
      case Err<List<Order>>(:final error):
        _state = ViewError(error.message);
    }
    notifyListeners();
  }

  /// How much [current] changed against [before], as a fraction (0.12 is 12% more), or `null` when [before] is
  /// zero and a percentage would mean nothing.
  static double? change(num current, num before) => before == 0 ? null : (current - before) / before;

  void setDays(int value) {
    if (value == _days) return;
    _days = value;
    unawaited(load());
  }

  void setKiosk(String? id) {
    if (id == _kioskId) return;
    _kioskId = id;
    unawaited(load());
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_kioskSub?.cancel());
    super.dispose();
  }
}
