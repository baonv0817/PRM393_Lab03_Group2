import 'package:breakbite_core/domain/models/app_user.dart';
import 'package:breakbite_core/utils/result.dart';

abstract interface class AuthService {
  /// Emits `null` while signed out.
  Stream<AppUser?> authStateChanges();

  /// Fails with `CancelledException` when the user closes the account picker, `NetworkException`
  /// without a connection, `ServiceException` otherwise.
  Future<Result<AppUser>> signInWithGoogle();

  /// Signs in an account made with [registerWithEmail]. Fails with `ValidationException` ("Email hoặc mật khẩu
  /// không đúng.") for an unknown email or a wrong password, so the message does not tell which one it was.
  Future<Result<AppUser>> signInWithEmail(String email, String password);

  /// Creates an account with an email and a password and signs it in. Fails with `ValidationException` when the
  /// email already has an account, the email is not valid or the password is too weak.
  Future<Result<AppUser>> registerWithEmail({required String name, required String email, required String password});

  Future<Result<void>> signOut();
}
