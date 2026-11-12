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
    this.defaultKioskId,
  });

  final String uid;
  final String displayName;
  final UserRole role;
  final String? email;
  final String? photoUrl;
  final String? studentId;
  final String? kioskId;
  final String? defaultKioskId;

  bool get isStaff => role == UserRole.staff || role == UserRole.admin;

  /// How a message names the account: the e-mail when there is one, else the display name. Used by the web and
  /// the mobile wrong-role messages, so they say the same thing (CR-F10).
  String get label => (email ?? '').isNotEmpty ? email! : displayName;
}
