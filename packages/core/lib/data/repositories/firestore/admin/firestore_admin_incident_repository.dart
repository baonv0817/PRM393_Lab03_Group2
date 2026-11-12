import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/repositories/admin/admin_incident_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAdminIncidentRepository implements AdminIncidentRepository {
  FirestoreAdminIncidentRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  @override
  Stream<List<Incident>> watchAll() => guardStream(
    _db
        .collection('incidents')
        .orderBy('createdAt', descending: true)
        .limit(AdminIncidentRepository.maxReports)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) incidentFromData(doc.id, doc.data(), now: _clock())]),
  );
}
