enum UserRole { user, staff, admin }

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.role,
    this.email,
    this.photoUrl,
    this.studentId,
    this.kioskId,
  });

  final String uid;
  final String displayName;
  final UserRole role;
  final String? email;
  final String? photoUrl;

  /// Mã số sinh viên (S16).
  final String? studentId;

  /// Kiosk nhân viên phụ trách; chỉ có với staff.
  final String? kioskId;

  bool get isStaff => role == UserRole.staff || role == UserRole.admin;
}
