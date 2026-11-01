import 'dart:async';

import 'package:breakbite/domain/app_exception.dart';

abstract interface class CrashService {
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});
  Future<void> setUserId(String uid);
  Future<void> setKey(String key, Object value);
  void forceTestCrash();
}

extension CrashServiceReporting on CrashService {
  void recordNonFatal(Object error, StackTrace? stack, String reason) {
    if (error is CancelledException) return;
    final cause = error is AppException ? error.cause ?? error : error;
    final trace = stack ?? (error is AppException ? error.stackTrace : null);
    unawaited(recordError(cause, trace, reason: reason));
  }
}
