import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// K13: what customers reported about their orders. Staff take a report on, then refund the order or turn
/// the report down with a reason; the customer sees the answer on S24 at once.
class SellerIncidentsViewModel extends ChangeNotifier with SafeChangeNotifier {
  SellerIncidentsViewModel({
    required this.incidents,
    required this.orders,
    required this.crash,
    required this.kioskId,
    required this.staffUid,
  }) {
    load();
  }

  static const noKioskMessage = 'Tài khoản này chưa được gán kiosk nên chưa có sự cố nào.';
  static const emptyMessage = 'Chưa có khách nào báo sự cố.';

  final IncidentRepository incidents;
  final OrderRepository orders;
  final CrashService crash;
  final String? kioskId;
  final String staffUid;

  StreamSubscription<List<Incident>>? _sub;
  ViewState<List<Incident>> _state = const ViewLoading();
  final _orderOf = <String, Order>{};
  final _loading = <String>{};
  String? _busyId;

  ViewState<List<Incident>> get state => _state;

  /// The order a report is about, once it has loaded (its dishes and what the customer paid).
  Order? orderOf(Incident incident) => _orderOf[incident.orderId];

  /// The id of the report being written, so its buttons show progress.
  String? get busyId => _busyId;

  int get openCount => (_state.dataOrNull ?? const []).where((i) => i.status != IncidentStatus.resolved).length;

  void load() {
    unawaited(_sub?.cancel());
    final id = kioskId;
    if (id == null || id.isEmpty) {
      _state = const ViewEmpty(noKioskMessage);
      notifyListeners();
      return;
    }
    _state = const ViewLoading();
    notifyListeners();
    _sub = incidents
        .watchKioskIncidents(id)
        .listen(
          (list) {
            _state = ViewStateX.fromList(list, emptyMessage: emptyMessage);
            notifyListeners();
            for (final incident in list) {
              unawaited(_loadOrder(incident));
            }
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'sellerIncidents.watch');
            _state = ViewError(error is AppException ? error.message : 'Không tải được danh sách sự cố.');
            notifyListeners();
          },
        );
  }

  Future<void> _loadOrder(Incident incident) async {
    final id = incident.orderId;
    if (_orderOf.containsKey(id) || !_loading.add(id)) return;
    try {
      final order = await orders.watchOrder(id).first;
      if (order != null) {
        _orderOf[id] = order;
        notifyListeners();
      }
    } catch (error, stack) {
      crash.recordNonFatal(error, stack, 'sellerIncidents.loadOrder');
    } finally {
      _loading.remove(id);
    }
  }

  /// What the customer paid for the order of [incident]: the most a refund may be.
  int? maxRefundOf(Incident incident) => orderOf(incident)?.totalVnd;

  Future<Result<void>> take(Incident incident) =>
      _run(incident, 'take', () => incidents.take(incident, staffUid: staffUid));

  /// "Hoàn tiền": the whole order by default; a smaller [amountVnd] for a partial refund.
  Future<Result<void>> refund(Incident incident, {int? amountVnd}) {
    final max = maxRefundOf(incident);
    final amount = amountVnd ?? max;
    final problem = incidentResolutionProblem(
      incident,
      IncidentResolution.refunded,
      refundVnd: amount,
      maxRefundVnd: max,
    );
    if (problem != null) return Future.value(Result.error(ValidationException(problem)));
    return _run(
      incident,
      'refund',
      () => incidents.resolve(incident, resolution: IncidentResolution.refunded, staffUid: staffUid, refundVnd: amount),
    );
  }

  Future<Result<void>> rejectReport(Incident incident, String reason) {
    final problem = incidentResolutionProblem(incident, IncidentResolution.rejected, note: reason);
    if (problem != null) return Future.value(Result.error(ValidationException(problem)));
    return _run(
      incident,
      'reject',
      () => incidents.resolve(incident, resolution: IncidentResolution.rejected, staffUid: staffUid, note: reason),
    );
  }

  Future<Result<void>> _run(Incident incident, String name, Future<Result<void>> Function() action) async {
    if (_busyId != null) return const Result.ok(null);
    _busyId = incident.orderId;
    notifyListeners();
    try {
      final result = await action();
      if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'sellerIncidents.$name');
      return result;
    } finally {
      _busyId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
