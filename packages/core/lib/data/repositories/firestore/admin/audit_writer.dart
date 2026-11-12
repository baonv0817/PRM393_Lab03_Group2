import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Builds the line of the audit log that goes into the same batch or transaction as the change it describes, so
/// a change is never saved without its line, nor a line without its change.
class AuditWriter {
  AuditWriter(this._db, this._actor);

  final FirebaseFirestore _db;
  final AdminActor Function() _actor;

  /// A reference for the new line: pass it to `batch.set(ref, data)` with [data].
  DocumentReference<Json> newRef() => _db.collection('audit_logs').doc();

  /// The fields of a line; the time is the server's.
  Json data({required String action, required String target, required String summary}) {
    final who = _actor();
    return {
      'actorUid': who.uid,
      'actorName': who.name,
      'action': action,
      'target': target,
      'summary': summary,
      ...Stamp.created(),
    };
  }

  /// Adds a line to [batch].
  void addTo(WriteBatch batch, {required String action, required String target, required String summary}) =>
      batch.set(newRef(), data(action: action, target: target, summary: summary));
}

AuditEntry auditEntryFromData(String id, Json data) => AuditEntry(
  id: id,
  actorUid: data['actorUid'] as String? ?? '',
  actorName: data['actorName'] as String? ?? '',
  action: data['action'] as String? ?? '',
  target: data['target'] as String? ?? '',
  summary: data['summary'] as String? ?? '',
  at: readDate(data['createdAt']) ?? DateTime.now(),
);
