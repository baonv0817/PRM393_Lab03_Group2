import 'package:breakbite_core/domain/models/models.dart';

/// The audit log of the admin website (A10): who changed what. Entries are written by the repositories that
/// make the changes, in the same write; this one only reads.
abstract interface class AuditLogRepository {
  /// The latest entries, newest first, live.
  Stream<List<AuditEntry>> watchRecent({int limit = 200});
}
