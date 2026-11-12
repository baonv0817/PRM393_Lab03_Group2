import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/admin/admin_user_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/audit_writer.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAdminUserRepository implements AdminUserRepository {
  FirestoreAdminUserRepository(this._db, this._audit);

  final FirebaseFirestore _db;
  final AuditWriter _audit;

  @override
  Stream<List<AppUser>> watchUsers() => guardStream(
    _db
        .collection('users')
        .limit(AdminUserRepository.maxUsers)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              appUserFromData(doc.id, doc.data(), fallbackName: doc.data()['email'] as String? ?? 'Tài khoản'),
          ]..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase())),
        ),
  );

  @override
  Future<Result<void>> setAccess(String uid, {required UserRole role, String? kioskId}) => guard(() async {
    final kiosk = kioskId?.trim() ?? '';
    if (role == UserRole.staff) {
      if (kiosk.isEmpty) throw const ValidationException('Nhân viên phải thuộc một kiosk.');
      if (!(await _db.doc('kiosks/$kiosk').get()).exists) throw ValidationException('Không có kiosk "$kiosk".');
    }
    final ref = _db.doc('users/$uid');
    final user = await ref.get();
    if (!user.exists) throw const NotFoundException(message: 'Không tìm thấy tài khoản này.');
    final name = user.data()?['displayName'] as String? ?? user.data()?['email'] as String? ?? uid;
    final batch = _db.batch()
      ..update(ref, {
        'role': role.name,
        'kioskId': role == UserRole.staff ? kiosk : FieldValue.delete(),
        ...Stamp.updated(),
      });
    _audit.addTo(
      batch,
      action: AuditAction.userAccess,
      target: 'users/$uid',
      summary: role == UserRole.staff ? 'Đặt $name làm staff của kiosk $kiosk' : 'Đặt vai trò ${role.name} cho $name',
    );
    await batch.commit();
  });
}
