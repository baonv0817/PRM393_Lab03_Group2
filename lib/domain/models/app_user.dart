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

  /// Student ID number (S16).
  final String? studentId;

  /// Kiosk the staff member is in charge of; staff only.
  final String? kioskId;

  bool get isStaff => role == UserRole.staff || role == UserRole.admin;
}
