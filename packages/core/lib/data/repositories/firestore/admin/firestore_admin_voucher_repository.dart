import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/admin/admin_voucher_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/audit_writer.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAdminVoucherRepository implements AdminVoucherRepository {
  FirestoreAdminVoucherRepository(this._db, this._audit);

  static const _limit = 200;

  final FirebaseFirestore _db;
  final AuditWriter _audit;

  @override
  Stream<List<Voucher>> watchAll() => guardStream(
    _db
        .collection('vouchers')
        .limit(_limit)
        .snapshots()
        .map(
          (snapshot) =>
              [for (final doc in snapshot.docs) ?voucherFromData(doc.id, doc.data())]
                ..sort((a, b) => b.expiresAt.compareTo(a.expiresAt)),
        ),
  );

  /// The discount as the rules want it: only the keys of its kind.
  Json _discount(VoucherDiscount discount) => switch (discount) {
    FixedDiscount(:final amountVnd) => {'type': 'fixed', 'amountVnd': amountVnd},
    PercentDiscount(:final percent, :final maxVnd) => {'type': 'percent', 'percent': percent, 'maxVnd': maxVnd},
  };

  String _describe(Voucher v) => switch (v.discount) {
    FixedDiscount(:final amountVnd) => 'giảm $amountVndđ',
    PercentDiscount(:final percent, :final maxVnd) => 'giảm $percent% tối đa $maxVndđ',
  };

  @override
  Future<Result<void>> save(Voucher voucher, {required bool isNew}) => guard(() async {
    final problem = VoucherRules.problemOf(voucher, isNew: isNew);
    if (problem != null) throw ValidationException(problem);
    final ref = _db.doc('vouchers/${voucher.code}');
    await _db.runTransaction((tx) async {
      final current = await tx.get(ref);
      if (isNew && current.exists) throw ValidationException('Mã ${voucher.code} đã có.');
      if (!isNew && !current.exists) throw const NotFoundException(message: 'Không tìm thấy mã này.');
      final fields = <String, Object>{
        'title': voucher.title.trim(),
        'discount': _discount(voucher.discount),
        'minOrderVnd': voucher.minOrderVnd,
        'expiresAt': Timestamp.fromDate(voucher.expiresAt),
        'active': voucher.active,
        if (voucher.startsAt != null) 'startsAt': Timestamp.fromDate(voucher.startsAt!),
        if (voucher.activeFrom != null) 'activeFrom': voucher.activeFrom!,
        if (voucher.activeTo != null) 'activeTo': voucher.activeTo!,
      };
      if (isNew) {
        tx.set(ref, {...fields, ...Stamp.created()});
      } else {
        tx.update(ref, {
          ...fields,
          if (voucher.startsAt == null) 'startsAt': FieldValue.delete(),
          if (voucher.activeFrom == null) 'activeFrom': FieldValue.delete(),
          if (voucher.activeTo == null) 'activeTo': FieldValue.delete(),
          ...Stamp.updated(),
        });
      }
      tx.set(
        _audit.newRef(),
        _audit.data(
          action: AuditAction.voucherSave,
          target: 'vouchers/${voucher.code}',
          summary: '${isNew ? 'Thêm' : 'Sửa'} mã ${voucher.code}: ${_describe(voucher)}',
        ),
      );
    });
  });

  @override
  Future<Result<void>> setActive(String code, bool active) => guard(() async {
    final ref = _db.doc('vouchers/$code');
    if (!(await ref.get()).exists) throw const NotFoundException(message: 'Không tìm thấy mã này.');
    final batch = _db.batch()..update(ref, {'active': active, ...Stamp.updated()});
    _audit.addTo(
      batch,
      action: AuditAction.voucherSave,
      target: 'vouchers/$code',
      summary: '${active ? 'Bật' : 'Tắt'} mã $code',
    );
    await batch.commit();
  });
}
