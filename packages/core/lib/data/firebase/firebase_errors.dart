import 'dart:async';

import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

AppException toAppException(Object error, [StackTrace? stack]) {
  if (error is AppException) return error;
  return switch (error) {
    FirebaseException(:final code) => _fromFirebaseCode(code, error, stack),
    GoogleSignInException(code: GoogleSignInExceptionCode.canceled || GoogleSignInExceptionCode.interrupted) =>
      CancelledException(message: 'Bạn đã huỷ đăng nhập.', cause: error, stackTrace: stack),
    GoogleSignInException() => ServiceException(
      message: 'Không đăng nhập được bằng Google. Thử lại sau.',
      cause: error,
      stackTrace: stack,
    ),
    TimeoutException() || http.ClientException() => NetworkException(cause: error, stackTrace: stack),
    _ => ServiceException(cause: error, stackTrace: stack),
  };
}

AppException _fromFirebaseCode(String code, Object error, StackTrace? stack) => switch (code) {
  'unavailable' || 'deadline-exceeded' || 'network-request-failed' => NetworkException(cause: error, stackTrace: stack),
  'permission-denied' ||
  'unauthenticated' ||
  'user-disabled' ||
  'requires-recent-login' => PermissionDeniedException(cause: error, stackTrace: stack),
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => ValidationException('Email hoặc mật khẩu không đúng.', cause: error, stackTrace: stack),
  'email-already-in-use' => ValidationException(
    'Email này đã có tài khoản. Hãy đăng nhập.',
    cause: error,
    stackTrace: stack,
  ),
  'invalid-email' => ValidationException('Email chưa đúng dạng.', cause: error, stackTrace: stack),
  'weak-password' => ValidationException(
    'Mật khẩu quá yếu. Dùng ít nhất 8 ký tự gồm chữ và số.',
    cause: error,
    stackTrace: stack,
  ),
  'operation-not-allowed' => ServiceException(
    message: 'Đăng nhập bằng email chưa được bật. Liên hệ quản trị viên.',
    cause: error,
    stackTrace: stack,
  ),
  'not-found' => NotFoundException(cause: error, stackTrace: stack),
  'cancelled' ||
  'popup-closed-by-user' ||
  'web-context-canceled' => CancelledException(cause: error, stackTrace: stack),
  'already-exists' => ValidationException('Dữ liệu này đã tồn tại.', cause: error, stackTrace: stack),
  'invalid-argument' || 'out-of-range' => ValidationException('Dữ liệu không hợp lệ.', cause: error, stackTrace: stack),
  'resource-exhausted' || 'too-many-requests' || 'quota-exceeded' => ServiceException(
    message: 'Hệ thống đang quá tải. Thử lại sau ít phút.',
    cause: error,
    stackTrace: stack,
  ),
  _ => ServiceException(cause: error, stackTrace: stack),
};

Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Result.ok(await action());
  } catch (error, stack) {
    return Result.error(toAppException(error, stack));
  }
}

Stream<T> guardStream<T>(Stream<T> source, {bool Function()? signedOut}) {
  final isSignedOut = signedOut ?? _noCurrentUser;
  return source.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleError: (error, stack, sink) {
        if (error is FirebaseException && error.code == 'permission-denied' && isSignedOut()) {
          sink.close();
          return;
        }
        sink.addError(toAppException(error, stack), stack);
      },
    ),
  );
}

bool _noCurrentUser() {
  try {
    return Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser == null;
  } catch (_) {
    return false;
  }
}
