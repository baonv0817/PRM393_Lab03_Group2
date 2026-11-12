import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/admin/admin_slot_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/audit_writer.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAdminSlotRepository implements AdminSlotRepository {
  FirestoreAdminSlotRepository(this._db, this._audit);

  /// A batch holds 500 writes: the slots and the audit line must fit in one, so the whole plan is all or nothing.
  static const _maxWrites = 400;

  final FirebaseFirestore _db;
  final AuditWriter _audit;

  CollectionReference<Json> _slots(String kioskId) => _db.collection('kiosks').doc(kioskId).collection('slots');

  @override
  Stream<List<PickupSlot>> watchSlots(String kioskId, {required DateTime from}) => guardStream(
    _slots(kioskId)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('startAt')
        .limit(_maxWrites)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) pickupSlotFromData(doc.id, doc.data())]),
  );

  @override
  Future<Result<SlotCreation>> createSlots(SlotPlan plan, {required DateTime from}) => guard(() async {
    final problem = plan.problem;
    if (problem != null) throw ValidationException(problem);
    if (!(await _db.doc('kiosks/${plan.kioskId}').get()).exists) {
      throw const NotFoundException(message: 'Không tìm thấy kiosk này.');
    }
    final wanted = plan.slots(from: from);
    if (wanted.isEmpty) throw const ValidationException('Không có khung giờ nào sắp tới trong các ngày đã chọn.');
    if (wanted.length > _maxWrites) throw const ValidationException('Quá nhiều khung giờ một lần. Chọn ít ngày hơn.');

    // Which of them exist: a window that does is left alone, so its bookings are not reset.
    final snapshot = await _slots(plan.kioskId)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(wanted.first.startAt))
        .where('startAt', isLessThanOrEqualTo: Timestamp.fromDate(wanted.last.startAt))
        .get();
    final have = {for (final doc in snapshot.docs) doc.id};
    final fresh = [
      for (final slot in wanted)
        if (!have.contains(slot.id)) slot,
    ];
    if (fresh.isEmpty) return SlotCreation(created: 0, existing: wanted.length);

    final batch = _db.batch();
    for (final slot in fresh) {
      batch.set(_slots(plan.kioskId).doc(slot.id), {
        'startAt': Timestamp.fromDate(slot.startAt),
        'endAt': Timestamp.fromDate(slot.endAt),
        'capacity': slot.capacity,
        'booked': 0,
        ...Stamp.created(),
      });
    }
    _audit.addTo(
      batch,
      action: AuditAction.slotsCreate,
      target: 'kiosks/${plan.kioskId}/slots',
      summary: 'Tạo ${fresh.length} khung giờ cho kiosk ${plan.kioskId} (${plan.days} ngày, sức chứa ${plan.capacity})',
    );
    await batch.commit();
    return SlotCreation(created: fresh.length, existing: wanted.length - fresh.length);
  });
}
