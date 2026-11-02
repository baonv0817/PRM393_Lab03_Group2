import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/data/firebase/firestore_helpers.dart';
import 'package:breakbite/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite/data/repositories/incident_repository.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';
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
}
