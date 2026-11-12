import 'package:breakbite_core/domain/models/models.dart';

/// The reports of customers across every kiosk, read-only, for the admin website (A07). Taking a report on, refunding
/// and rejecting it stay with the staff of the kiosk (K13).
abstract interface class AdminIncidentRepository {
  /// Most reports the list holds.
  static const maxReports = 200;

  /// The newest reports of every kiosk, live.
  Stream<List<Incident>> watchAll();
}
