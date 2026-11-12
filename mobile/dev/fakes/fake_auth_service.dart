import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

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
    kioskId: role == UserRole.user ? null : 'q9-t2',
  );

  /// For tests: the profile changes while the app is open, as when an admin assigns a kiosk to a staff member.
  void setKiosk(String? kioskId) {
    final current = _user.value;
    if (current == null) return;
    _user.set(AppUser(uid: current.uid, displayName: current.displayName, role: current.role, kioskId: kioskId));
  }

  @override
  Stream<AppUser?> authStateChanges() => _user.stream;

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    final user = _make(role);
    _user.set(user);
    return Result.ok(user);
  }

  /// Accounts made with [registerWithEmail], by email: a fake has no server to remember them.
  final _accounts = <String, ({String name, String password})>{};

  @override
  Future<Result<AppUser>> signInWithEmail(String email, String password) async {
    final key = email.trim().toLowerCase();
    final account = _accounts[key];
    if (account == null) {
      // The demo account signs in as the fake role, so the screens can be tried without registering.
      if (key == 'user@breakbite.dev' && password == 'breakbite1') {
        final user = _make(role);
        _user.set(user);
        return Result.ok(user);
      }
      return const Result.error(ValidationException('Email hoặc mật khẩu không đúng.'));
    }
    if (account.password != password) {
      return const Result.error(ValidationException('Email hoặc mật khẩu không đúng.'));
    }
    final user = AppUser(uid: 'dev-$key', displayName: account.name, role: UserRole.user, email: key);
    _user.set(user);
    return Result.ok(user);
  }

  @override
  Future<Result<AppUser>> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      return const Result.error(ValidationException('Email này đã có tài khoản. Hãy đăng nhập.'));
    }
    _accounts[key] = (name: name.trim(), password: password);
    final user = AppUser(uid: 'dev-$key', displayName: name.trim(), role: UserRole.user, email: key);
    _user.set(user);
    return Result.ok(user);
  }

  @override
  Future<Result<void>> signOut() async {
    _user.set(null);
    return const Result.ok(null);
  }
}
