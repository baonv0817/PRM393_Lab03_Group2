import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/repositories/admin/audit_log_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/audit_writer.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAuditLogRepository implements AuditLogRepository {
  FirestoreAuditLogRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<AuditEntry>> watchRecent({int limit = 200}) => guardStream(
    _db
        .collection('audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) auditEntryFromData(doc.id, doc.data())]),
  );
}
