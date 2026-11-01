import 'package:breakbite/data/services/crash_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseCrashService implements CrashService {
  FirebaseCrashService(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason}) async {
    try {
      await _crashlytics.recordError(error, stack, reason: reason, fatal: false);
    } catch (e) {
      debugPrint('Crashlytics did not record $error: $e');
    }
  }

  @override
  Future<void> setUserId(String uid) async {
    try {
      await _crashlytics.setUserIdentifier(uid);
    } catch (e) {
      debugPrint('Crashlytics user id was not set: $e');
    }
  }

  @override
  Future<void> setKey(String key, Object value) async {
    try {
      await _crashlytics.setCustomKey(key, crashKeyValue(value));
    } catch (e) {
      debugPrint('Crashlytics key $key was not set: $e');
    }
  }

  @override
  void forceTestCrash() => _crashlytics.crash();
}

Object crashKeyValue(Object value) => switch (value) {
  bool() || int() || double() || String() => value,
  Enum(:final name) => name,
  _ => value.toString(),
};
