import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/data/repositories/incident_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

class FirestoreIncidentRepository implements IncidentRepository {
  FirestoreIncidentRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  CollectionReference<Json> get _incidents => _db.collection('incidents');

  /// The id is the order id, so the rules allow one report per order: a second `set` is refused.
  @override
  Future<Result<Incident>> report({
    required Order order,
    required IncidentType type,
    required String description,
    String customerName = '',
  }) => guard(() async {
    final text = description.trim();
    if (text.isEmpty) throw const ValidationException('Hãy mô tả sự cố.');
    if (text.length > IncidentRepository.maxDescriptionLength) {
      throw const ValidationException('Mô tả tối đa ${IncidentRepository.maxDescriptionLength} ký tự.');
    }
    final name = customerName.trim();
    await _incidents.doc(order.id).set({
      'orderId': order.id,
      'kioskId': order.kioskId,
      'uid': order.uid,
      if (name.isNotEmpty) 'customerName': name,
      'type': type.name,
      'description': text,
      'status': IncidentStatus.open.name,
      ...Stamp.created(),
    });
    return Incident(
      orderId: order.id,
      kioskId: order.kioskId,
      uid: order.uid,
      customerName: name,
      type: type,
      description: text,
      status: IncidentStatus.open,
      createdAt: _clock(),
    );
  });

  /// A query, not a `get` of the document: the rules read `resource.data.uid`, so reading a document that
  /// does not exist yet would be refused, while a query filtered by the customer's uid is allowed.
  @override
  Stream<Incident?> watchOfOrder(String uid, String orderId) => guardStream(
    _incidents
        .where('uid', isEqualTo: uid)
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : incidentFromData(snapshot.docs.first.id, snapshot.docs.first.data(), now: _clock()),
        ),
  );

  @override
  Stream<List<Incident>> watchKioskIncidents(String kioskId) => guardStream(
    // No orderBy: it would need one more composite index, and the list is sorted here anyway.
    _incidents
        .where('kioskId', isEqualTo: kioskId)
        .snapshots()
        .map(
          (snapshot) =>
              sortIncidentsForStaff([for (final d in snapshot.docs) incidentFromData(d.id, d.data(), now: _clock())]),
        ),
  );

  @override
  Future<Result<void>> take(Incident incident, {required String staffUid}) {
    final ref = _incidents.doc(incident.orderId);
    return runGuardedTransaction<void>(_db, (tx) async {
      await _expectNotResolved(tx, ref);
      tx.update(ref, {'status': IncidentStatus.inProgress.name, ...Stamp.updated()});
    });
  }

  /// Reads the document inside the transaction: the incident the screen holds may be older than what another
  /// staff member has just done, and a resolved report must not be taken again or answered twice.
  Future<void> _expectNotResolved(Transaction tx, DocumentReference<Json> ref) async {
    final snapshot = await tx.get(ref);
    if (!snapshot.exists) throw const NotFoundException(message: 'Không tìm thấy báo cáo sự cố.');
    if (snapshot.data()?['status'] == IncidentStatus.resolved.name) throw const PermissionDeniedException();
  }

  @override
  Future<Result<void>> resolve(
    Incident incident, {
    required IncidentResolution resolution,
    required String staffUid,
    int? refundVnd,
    String? note,
  }) {
    final problem = incidentResolutionProblem(incident, resolution, refundVnd: refundVnd, note: note);
    if (problem != null) return Future.value(Result.error(ValidationException(problem)));
    final ref = _incidents.doc(incident.orderId);
    return runGuardedTransaction<void>(_db, (tx) async {
      await _expectNotResolved(tx, ref);
      tx.update(ref, {
        'status': IncidentStatus.resolved.name,
        'resolution': resolution.name,
        if (resolution == IncidentResolution.refunded) 'refundVnd': refundVnd,
        if ((note ?? '').trim().isNotEmpty) 'resolutionNote': note!.trim(),
        'resolvedAt': FieldValue.serverTimestamp(),
        'handledBy': staffUid,
        ...Stamp.updated(),
      });
    });
  }
}
