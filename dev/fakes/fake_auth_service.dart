import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.role = UserRole.user, bool signedIn = false})
    : _user = LiveValue<AppUser?>(signedIn ? _make(role) : null);

  final UserRole role;
  final LiveValue<AppUser?> _user;

  static AppUser _make(UserRole role) => AppUser(
    uid: role == UserRole.user ? 'dev-user' : 'dev-staff',
    displayName: role == UserRole.user ? 'Minh Quân' : 'Cô Hạnh',
    role: role,
  );

  @override
  Stream<AppUser?> authStateChanges() => _user.stream;

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    final user = _make(role);
    _user.set(user);
    return Result.ok(user);
  }

  @override
  Future<Result<void>> signOut() async {
    _user.set(null);
    return const Result.ok(null);
  }
}
