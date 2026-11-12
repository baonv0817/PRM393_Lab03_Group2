import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/admin/admin_order_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/paged.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

class FirestoreAdminOrderRepository implements AdminOrderRepository {
  FirestoreAdminOrderRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  Order _fromDoc(QueryDocumentSnapshot<Json> doc) => orderFromData(doc.id, doc.data(), now: _clock());

  /// Always newest first on `createdAt`: that is the order of the composite indexes, so every mix of filters finds
  /// its index (`firestore.indexes.json`).
  Query<Json> _query(OrderQuery q) {
    Query<Json> query = _db.collection('orders');
    if (q.kioskId != null) query = query.where('kioskId', isEqualTo: q.kioskId);
    if (q.status != null) query = query.where('status', isEqualTo: q.status!.name);
    if (q.from != null) query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(q.from!));
    if (q.to != null) query = query.where('createdAt', isLessThan: Timestamp.fromDate(q.to!));
    return query.orderBy('createdAt', descending: true);
  }

  @override
  Future<Result<Paged<Order>>> fetchOrders(OrderQuery query, {int limit = 25, PageCursor? after}) =>
      fetchPage(_query(query), fromDoc: _fromDoc, limit: limit, after: after);

  @override
  Future<Result<List<Order>>> fetchRange({required DateTime from, required DateTime to, String? kioskId}) =>
      guard(() async {
        final snapshot = await _query(OrderQuery(kioskId: kioskId, from: from, to: to))
            .limit(AdminOrderRepository.maxRange)
            .get();
        return [for (final doc in snapshot.docs) _fromDoc(doc)];
      });
}
