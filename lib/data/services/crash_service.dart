abstract interface class CrashService {
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});
  Future<void> setUserId(String uid);
  Future<void> setKey(String key, Object value);

  /// Only used by the Firebase demo area.
  void forceTestCrash();
}
