import '../../domain/models/app_user.dart';

/// Đăng nhập bị người dùng huỷ.
class AuthCancelled implements Exception {
  const AuthCancelled();
}

/// Đăng nhập lỗi (mất mạng, bị từ chối…).
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

abstract interface class AuthService {
  /// `null` khi chưa đăng nhập.
  Stream<AppUser?> authStateChanges();

  /// Ném [AuthCancelled] khi huỷ, [AuthFailure] khi lỗi.
  Future<AppUser> signInWithGoogle();

  Future<void> signOut();
}
