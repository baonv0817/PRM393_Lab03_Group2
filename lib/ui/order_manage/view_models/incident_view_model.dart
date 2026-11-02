import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// S24: report a problem with an order that was received. An order has at most one report, so once it is
/// sent the screen shows the report and how the kiosk handles it instead of the form.
class IncidentViewModel extends ChangeNotifier with SafeChangeNotifier {
  IncidentViewModel({
    required this.orders,
    required this.incidents,
    required this.crash,
    required this.uid,
    required this.customerName,
    required this.orderId,
  }) {
    submit = Command0(_submit);
    load();
  }

  static const notFoundMessage = 'Không tìm thấy đơn này.';
  static const notDeliveredMessage = 'Bạn chỉ báo được sự cố sau khi đã nhận món.';
  static const maxDescriptionLength = IncidentRepository.maxDescriptionLength;

  /// The kinds of problem, in the order they are offered.
  static const types = [
    IncidentType.missingItem,
    IncidentType.wrongItem,
    IncidentType.quality,
    IncidentType.late,
    IncidentType.other,
  ];

  final OrderRepository orders;
  final IncidentRepository incidents;
  final CrashService crash;
  final String uid;
  final String customerName;
  final String orderId;

  late final Command0<Incident> submit;

  StreamSubscription<Order?>? _orderSub;
  StreamSubscription<Incident?>? _incidentSub;
  Order? _order;
  Incident? _incident;
  bool _orderLoaded = false;
  bool _incidentLoaded = false;
  String? _loadError;
  IncidentType? _type;
  String _description = '';

  Order? get order => _order;

  /// The report already sent for this order, if any.
  Incident? get incident => _incident;

  ViewState<Order> get state {
    if (_loadError case final message?) return ViewError(message);
    if (!_orderLoaded || !_incidentLoaded) return const ViewLoading();
    final o = _order;
    if (o == null) return const ViewEmpty(notFoundMessage);
    if (_incident == null && o.status != OrderStatus.delivered) return const ViewEmpty(notDeliveredMessage);
    return ViewData(o);
  }

  void load() {
    unawaited(_orderSub?.cancel());
    unawaited(_incidentSub?.cancel());
    _order = null;
    _incident = null;
    _orderLoaded = false;
    _incidentLoaded = false;
    _loadError = null;
    notifyListeners();
    _orderSub = orders.watchOrder(orderId).listen((value) {
      _order = value;
      _orderLoaded = true;
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => _fail(error, stack, 'incident.watchOrder'));
    _incidentSub = incidents.watchOfOrder(uid, orderId).listen((value) {
      _incident = value;
      _incidentLoaded = true;
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => _fail(error, stack, 'incident.watchIncident'));
  }

  void _fail(Object error, StackTrace stack, String where) {
    crash.recordNonFatal(error, stack, where);
    _loadError = error is AppException ? error.message : 'Không tải được đơn hàng.';
    notifyListeners();
  }

  IncidentType? get type => _type;

  String get description => _description;

  void selectType(IncidentType value) {
    if (value == _type) return;
    _type = value;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value.length > maxDescriptionLength ? value.substring(0, maxDescriptionLength) : value;
    notifyListeners();
  }

  bool get canSubmit => _type != null && _description.trim().isNotEmpty;

  /// What is still missing before the report can be sent.
  String? get missingHint {
    if (_type == null) return 'Chọn loại sự cố.';
    if (_description.trim().isEmpty) return 'Mô tả điều đã xảy ra để kiosk kiểm tra.';
    return null;
  }

  int get charactersLeft => maxDescriptionLength - _description.length;

  Future<Result<Incident>> _submit() async {
    final o = _order;
    final selected = _type;
    if (o == null) return const Result.error(NotFoundException(message: notFoundMessage));
    if (selected == null) return const Result.error(ValidationException('Chọn loại sự cố.'));
    final result = await incidents.report(
      order: o,
      type: selected,
      description: _description,
      customerName: customerName,
    );
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'incident.report');
    return result;
  }

  String get sentAtLine {
    final i = _incident;
    return i == null ? '' : 'Gửi lúc ${formatDateTime(i.createdAt)}';
  }

  String get statusLabel => _incident == null ? '' : incidentStatusLabel(_incident!.status);

  String get typeLabel => _incident == null ? '' : incidentTypeLabel(_incident!.type);

  /// The kiosk's answer once the report is handled; `null` while it is open or being looked at.
  String? get resolutionLine {
    final i = _incident;
    if (i == null || i.status != IncidentStatus.resolved) return null;
    return switch (i.resolution) {
      IncidentResolution.refunded => 'Kiosk đồng ý hoàn ${formatVnd(i.refundVnd ?? 0)} cho bạn.',
      IncidentResolution.rejected => 'Kiosk không nhận báo cáo này: ${i.resolutionNote ?? 'không có ghi chú'}',
      null => 'Kiosk đã xử lý báo cáo này.',
    };
  }

  @override
  void dispose() {
    unawaited(_orderSub?.cancel());
    unawaited(_incidentSub?.cancel());
    submit.dispose();
    super.dispose();
  }
}
