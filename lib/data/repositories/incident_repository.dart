import 'package:breakbite/domain/models/incident.dart';
import 'package:breakbite/domain/models/order.dart';
import 'package:breakbite/utils/result.dart';

abstract interface class IncidentRepository {
  static const maxDescriptionLength = 500;

  /// The customer reports a problem with one of their orders (S24). There is at most one report per
  /// order: a second one is refused. Fails with `ValidationException` when the description is empty or
  /// longer than [maxDescriptionLength], `PermissionDeniedException` when the order already has a report
  /// or is not the customer's, or `NetworkException`.
  Future<Result<Incident>> report({
    required Order order,
    required IncidentType type,
    required String description,
    String customerName = '',
  });

  /// The customer's report about [orderId], `null` while there is none; it follows the kiosk's handling.
  /// Takes the uid because the rules only let the owner (or the kiosk's staff) read it.
  Stream<Incident?> watchOfOrder(String uid, String orderId);

  /// K13: the reports of a kiosk, open and in progress first, then the answered ones, newest first.
  Stream<List<Incident>> watchKioskIncidents(String kioskId);

  /// K13: the staff member takes a report on ("inProgress").
  Future<Result<void>> take(Incident incident, {required String staffUid});

  /// K13: refunds the order (`refundVnd` > 0 and at most what the customer paid) or rejects the report with a
  /// reason. Fails with `ValidationException` for a bad amount or an empty reason, and with
  /// `PermissionDeniedException` when the report is already answered or is not of this staff's kiosk.
  Future<Result<void>> resolve(
    Incident incident, {
    required IncidentResolution resolution,
    required String staffUid,
    int? refundVnd,
    String? note,
  });
}

/// Why a K13 answer cannot be saved, or `null` when it can. A refund needs an amount between 1 and
/// [maxRefundVnd]; a rejection needs a reason (the rules ask for the same).
String? incidentResolutionProblem(
  Incident incident,
  IncidentResolution resolution, {
  int? refundVnd,
  String? note,
  int? maxRefundVnd,
}) {
  switch (resolution) {
    case IncidentResolution.refunded:
      if (refundVnd == null || refundVnd <= 0) return 'Nhập số tiền hoàn lớn hơn 0.';
      if (maxRefundVnd != null && refundVnd > maxRefundVnd) return 'Không hoàn quá số khách đã trả.';
    case IncidentResolution.rejected:
      if ((note ?? '').trim().isEmpty) return 'Nhập lý do từ chối để khách biết.';
  }
  return null;
}

/// Open reports first, then those in progress, then the answered ones; newest first inside each group.
List<Incident> sortIncidentsForStaff(List<Incident> incidents) {
  int rank(Incident i) => switch (i.status) {
    IncidentStatus.open => 0,
    IncidentStatus.inProgress => 1,
    IncidentStatus.resolved => 2,
  };
  return [...incidents]..sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : b.createdAt.compareTo(a.createdAt);
  });
}
