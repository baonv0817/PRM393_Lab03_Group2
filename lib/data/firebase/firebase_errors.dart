import 'dart:async';

import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/utils/result.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Turns any error thrown by Firebase, Google Sign-In or HTTP into the one [AppException] the rest
/// of the app understands. Every Firebase implementation goes through this function (or [guard]),
/// so the same failure always shows the same message.
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
  'not-found' || 'user-not-found' => NotFoundException(cause: error, stackTrace: stack),
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

/// Runs [action] and wraps its outcome in a [Result]: the standard body of every one-shot method
/// of a Firebase repository or service.
///
/// ```dart
/// Future<Result<void>> setSoldOut(String id, bool soldOut) =>
///     guard(() => _items.doc(id).update({'soldOut': soldOut, ...Stamp.updated()}));
/// ```
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Result.ok(await action());
  } catch (error, stack) {
    return Result.error(toAppException(error, stack));
  }
}

/// Maps the error events of a realtime stream to [AppException], so view models see the same
/// types as with [guard].
Stream<T> guardStream<T>(Stream<T> source) =>
    source.handleError((Object error, StackTrace stack) => throw toAppException(error, stack));
