import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/data/repositories/voucher_repository.dart';
import 'package:breakbite_core/domain/models/voucher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreVoucherRepository implements VoucherRepository {
  FirestoreVoucherRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Voucher>> watchActiveVouchers() => guardStream(
    _db
        .collection('vouchers')
        .where('active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              [for (final doc in snapshot.docs) ?voucherFromData(doc.id, doc.data())]
                ..sort((a, b) => a.code.compareTo(b.code)),
        ),
  );
}
