import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/admin/admin_kiosk_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/audit_writer.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAdminKioskRepository implements AdminKioskRepository {
  FirestoreAdminKioskRepository(this._db, this._audit);

  static final _id = RegExp(r'^[a-z0-9][a-z0-9-]{1,29}$');

  final FirebaseFirestore _db;
  final AuditWriter _audit;

  /// Empty fields are removed, so an update without hours really has none.
  Map<String, Object> _fields(Kiosk k) {
    final notice = k.notice?.trim() ?? '';
    return {
      'name': k.name.trim(),
      'location': k.location.trim(),
      'open': k.open,
      'waitMinutes': k.waitMinutes,
      'openTime': k.openTime ?? FieldValue.delete(),
      'closeTime': k.closeTime ?? FieldValue.delete(),
      'notice': notice.isEmpty ? FieldValue.delete() : notice,
      'maxOrdersPerSlot': k.maxOrdersPerSlot ?? FieldValue.delete(),
    };
  }

  @override
  Future<Result<void>> save(Kiosk kiosk, {required bool isNew}) => guard(() async {
    if (kiosk.name.trim().isEmpty) throw const ValidationException('Nhập tên kiosk.');
    final problem = KioskSettings.of(kiosk).problem;
    if (problem != null) throw ValidationException(problem);
    if (isNew && !_id.hasMatch(kiosk.id)) {
      throw const ValidationException('Mã kiosk gồm chữ thường, số và dấu gạch ngang, 2 đến 30 ký tự.');
    }
    final ref = _db.doc('kiosks/${kiosk.id}');
    await _db.runTransaction((tx) async {
      final current = await tx.get(ref);
      if (isNew && current.exists) throw ValidationException('Mã kiosk "${kiosk.id}" đã có.');
      if (!isNew && !current.exists) throw const NotFoundException(message: 'Không tìm thấy kiosk này.');
      final fields = _fields(kiosk);
      if (isNew) {
        // A new document has no field to remove: only the values.
        tx.set(ref, {
          for (final entry in fields.entries)
            if (entry.value is! FieldValue) entry.key: entry.value,
          ...Stamp.created(),
        });
      } else {
        tx.update(ref, {...fields, ...Stamp.updated()});
      }
      tx.set(
        _audit.newRef(),
        _audit.data(
          action: AuditAction.kioskSave,
          target: 'kiosks/${kiosk.id}',
          summary: isNew ? 'Thêm kiosk ${kiosk.name.trim()}' : 'Sửa kiosk ${kiosk.name.trim()}',
        ),
      );
    });
  });
}
