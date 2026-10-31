abstract interface class CrashService {
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});
  Future<void> setUserId(String uid);
  Future<void> setKey(String key, Object value);

  /// Chỉ dùng cho khu demo Firebase.
  void forceTestCrash();
}
