import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

import '../live_value.dart';
import 'fake_audit_log.dart';

class FakeAdminUserRepository implements AdminUserRepository {
  FakeAdminUserRepository(this.audit, {List<AppUser>? users, this.kioskIds = const {'q9-t2', 'q9-t4', 'nvh-t1'}})
    : _users = LiveValue(users ?? _seed);

  static const _seed = [
    AppUser(uid: 'dev-admin', displayName: 'Quản trị viên', role: UserRole.admin, email: 'admin@breakbite.dev'),
    AppUser(
      uid: 'staff-1',
      displayName: 'Cô Hạnh',
      role: UserRole.staff,
      email: 'hanh@breakbite.dev',
      kioskId: 'q9-t2',
    ),
    AppUser(uid: 'user-1', displayName: 'Nguyễn Minh Quân', role: UserRole.user, email: 'quan@fpt.edu.vn'),
    AppUser(uid: 'user-2', displayName: 'Trần Bảo An', role: UserRole.user, email: 'an@fpt.edu.vn'),
  ];

  final FakeAuditLog audit;

  /// The kiosks that exist, for the check of a staff member's kiosk.
  final Set<String> kioskIds;
  final LiveValue<List<AppUser>> _users;
  AppException? failNext;

  List<AppUser> get users => _users.value;

  AppUser byUid(String uid) => users.firstWhere((u) => u.uid == uid);

  @override
  Stream<List<AppUser>> watchUsers() => _users.stream;

  @override
  Future<Result<void>> setAccess(String uid, {required UserRole role, String? kioskId}) async {
    if (failNext case final error?) {
      failNext = null;
      return Result.error(error);
    }
    final kiosk = kioskId?.trim() ?? '';
    if (role == UserRole.staff) {
      if (kiosk.isEmpty) return const Result.error(ValidationException('Nhân viên phải thuộc một kiosk.'));
      if (!kioskIds.contains(kiosk)) return Result.error(ValidationException('Không có kiosk "$kiosk".'));
    }
    final index = users.indexWhere((u) => u.uid == uid);
    if (index < 0) return const Result.error(NotFoundException(message: 'Không tìm thấy tài khoản này.'));
    final old = users[index];
    final next = AppUser(
      uid: old.uid,
      displayName: old.displayName,
      role: role,
      email: old.email,
      photoUrl: old.photoUrl,
      studentId: old.studentId,
      kioskId: role == UserRole.staff ? kiosk : null,
      defaultKioskId: old.defaultKioskId,
    );
    _users.set([...users]..[index] = next);
    audit.record(
      AuditAction.userAccess,
      'users/$uid',
      role == UserRole.staff
          ? 'Đặt ${old.displayName} làm staff của kiosk $kiosk'
          : 'Đặt vai trò ${role.name} cho ${old.displayName}',
    );
    return const Result.ok(null);
  }
}
