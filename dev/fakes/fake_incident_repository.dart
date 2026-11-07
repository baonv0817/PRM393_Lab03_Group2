import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';

/// Behaves like the Firestore version: one report per order, validated description, and the report of an
/// order is only visible to its owner.
class FakeIncidentRepository implements IncidentRepository {
  final _incidents = LiveValue<List<Incident>>(const []);
  var _clock = DateTime(2026, 11, 2, 11);
  AppException? failNextReport;

  List<Incident> get all => _incidents.value;

  @override
  Future<Result<Incident>> report({
    required Order order,
    required IncidentType type,
    required String description,
    String customerName = '',
  }) async {
    if (failNextReport case final error?) {
      failNextReport = null;
      return Result.error(error);
    }
    final text = description.trim();
    if (text.isEmpty) return const Result.error(ValidationException('Hãy mô tả sự cố.'));
    if (text.length > IncidentRepository.maxDescriptionLength) {
      return const Result.error(ValidationException('Mô tả tối đa ${IncidentRepository.maxDescriptionLength} ký tự.'));
    }
    if (all.any((i) => i.orderId == order.id)) return const Result.error(PermissionDeniedException());
    _clock = _clock.add(const Duration(minutes: 1));
    final incident = Incident(
      orderId: order.id,
      kioskId: order.kioskId,
      uid: order.uid,
      customerName: customerName,
      type: type,
      description: text,
      status: IncidentStatus.open,
      createdAt: _clock,
    );
    _incidents.set([incident, ..._incidents.value]);
    return Result.ok(incident);
  }

  @override
  Stream<Incident?> watchOfOrder(String uid, String orderId) =>
      _incidents.stream.map((list) => list.where((i) => i.uid == uid && i.orderId == orderId).firstOrNull);

  @override
  Stream<List<Incident>> watchKioskIncidents(String kioskId) =>
      _incidents.stream.map((l) => sortIncidentsForStaff(l.where((i) => i.kioskId == kioskId).toList()));

  @override
  Future<Result<void>> take(Incident incident, {required String staffUid}) async {
    final current = all.where((i) => i.orderId == incident.orderId).firstOrNull;
    if (current == null) return const Result.error(NotFoundException());
    if (current.status == IncidentStatus.resolved) return const Result.error(PermissionDeniedException());
    handle(incident.orderId, status: IncidentStatus.inProgress);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> resolve(
    Incident incident, {
    required IncidentResolution resolution,
    required String staffUid,
    int? refundVnd,
    String? note,
  }) async {
    final problem = incidentResolutionProblem(incident, resolution, refundVnd: refundVnd, note: note);
    if (problem != null) return Result.error(ValidationException(problem));
    final current = all.where((i) => i.orderId == incident.orderId).firstOrNull;
    if (current == null) return const Result.error(NotFoundException());
    if (current.status == IncidentStatus.resolved) return const Result.error(PermissionDeniedException());
    handle(
      incident.orderId,
      status: IncidentStatus.resolved,
      resolution: resolution,
      refundVnd: refundVnd,
      resolutionNote: note?.trim(),
    );
    return const Result.ok(null);
  }

  /// What kiosk staff do in K13, for tests: take the report on, refund it or reject it.
  void handle(
    String orderId, {
    required IncidentStatus status,
    IncidentResolution? resolution,
    int? refundVnd,
    String? resolutionNote,
  }) {
    _clock = _clock.add(const Duration(minutes: 1));
    _incidents.set([
      for (final i in _incidents.value)
        if (i.orderId == orderId)
          Incident(
            orderId: i.orderId,
            kioskId: i.kioskId,
            uid: i.uid,
            customerName: i.customerName,
            type: i.type,
            description: i.description,
            status: status,
            createdAt: i.createdAt,
            resolution: resolution,
            refundVnd: refundVnd,
            resolutionNote: resolutionNote,
            handledBy: 'staff-1',
            resolvedAt: status == IncidentStatus.resolved ? _clock : null,
          )
        else
          i,
    ]);
  }
}
