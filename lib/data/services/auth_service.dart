import 'package:breakbite/domain/models/app_user.dart';
import 'package:breakbite/utils/result.dart';

abstract interface class AuthService {
  /// Emits `null` while signed out.
  Stream<AppUser?> authStateChanges();

  /// Fails with `CancelledException` when the user closes the account picker, `NetworkException`
  /// without a connection, `ServiceException` otherwise.
  Future<Result<AppUser>> signInWithGoogle();

  Future<Result<void>> signOut();
}
