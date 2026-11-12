import 'dart:async';

import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// A07: the reports of customers across every kiosk, with how each was answered. The admin only reads: the staff
/// of the kiosk take a report on and answer it (K13). The open ones come first, then the ones being handled, then
/// the answered, each newest first.
class AdminIncidentsViewModel extends ChangeNotifier with SafeChangeNotifier {
  AdminIncidentsViewModel({required this.incidents, required this.menu, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    load();
  }

  static const emptyMessage = 'Chưa có khách nào báo sự cố.';

  final AdminIncidentRepository incidents;
  final MenuRepository menu;
  final DateTime Function() _clock;

  StreamSubscription<List<Incident>>? _sub;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  ViewState<List<Incident>> _state = const ViewLoading();
  List<Kiosk> _kiosks = const [];
  IncidentStatus? _status;
  String? _kioskId;

  ViewState<List<Incident>> get state => _state;
  List<Kiosk> get kiosks => _kiosks;
  IncidentStatus? get status => _status;
  String? get kioskId => _kioskId;

  String kioskName(String id) => _kiosks.where((k) => k.id == id).firstOrNull?.name ?? id;

  int countOf(IncidentStatus status) =>
      (_state.dataOrNull ?? const <Incident>[]).where((i) => i.status == status).length;

  /// Reports that nobody has answered yet and are older than a day: they need a nudge to the counter.
  int get overdue => (_state.dataOrNull ?? const <Incident>[])
      .where((i) => i.status != IncidentStatus.resolved && _clock().difference(i.createdAt) > const Duration(days: 1))
      .length;

  List<Incident> get visible {
    final all = _state.dataOrNull ?? const <Incident>[];
    return [
      for (final i in all)
        if ((_status == null || i.status == _status) && (_kioskId == null || i.kioskId == _kioskId)) i,
    ]..sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      return byStatus != 0 ? byStatus : b.createdAt.compareTo(a.createdAt);
    });
  }

  void load() {
    unawaited(_sub?.cancel());
    unawaited(_kioskSub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _sub = incidents.watchAll().listen(
      (list) {
        _state = list.isEmpty ? const ViewEmpty(emptyMessage) : ViewData(list);
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        _state = ViewError(error is AppException ? error.message : 'Không tải được danh sách sự cố.');
        notifyListeners();
      },
    );
    _kioskSub = menu.watchKiosks().listen((list) {
      _kiosks = list;
      notifyListeners();
    }, onError: (Object e, StackTrace s) {});
  }

  void setStatus(IncidentStatus? value) {
    _status = value;
    notifyListeners();
  }

  void setKiosk(String? id) {
    _kioskId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_kioskSub?.cancel());
    super.dispose();
  }
}
