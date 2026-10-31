abstract interface class AnalyticsService {
  Future<void> logEvent(String name, [Map<String, Object>? parameters]);
  Future<void> setUserId(String? uid);
}
