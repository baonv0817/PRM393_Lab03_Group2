import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite/data/repositories/slot_repository.dart';
import 'package:breakbite/domain/models/pickup_slot.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSlotRepository implements SlotRepository {
  FirestoreSlotRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<PickupSlot>> watchUpcomingSlots(String kioskId, {required DateTime from}) => guardStream(
    _db
        .collection('kiosks')
        .doc(kioskId)
        .collection('slots')
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('startAt')
        .limit(SlotRepository.upcomingLimit)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) pickupSlotFromData(doc.id, doc.data())]),
  );
}
