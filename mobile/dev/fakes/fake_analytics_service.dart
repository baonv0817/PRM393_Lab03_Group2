import 'package:breakbite_core/data/services/services.dart';

class FakeAnalyticsService implements AnalyticsService {
  final events = <({String name, Map<String, Object>? params})>[];
  String? userId;

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async =>
      events.add((name: name, params: parameters));

  @override
  Future<void> setUserId(String? uid) async => userId = uid;
}
