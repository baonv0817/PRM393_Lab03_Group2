import 'package:breakbite/data/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this._analytics);

  static const maxStringLength = 100;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters == null ? null : analyticsParameters(parameters));
    } catch (error) {
      debugPrint('Analytics event $name was not logged: $error');
    }
  }

  @override
  Future<void> setUserId(String? uid) async {
    try {
      await _analytics.setUserId(id: uid);
    } catch (error) {
      debugPrint('Analytics user id was not set: $error');
    }
  }
}

Map<String, Object> analyticsParameters(Map<String, Object> parameters) => {
  for (final MapEntry(:key, :value) in parameters.entries)
    key: switch (value) {
      final bool flag => flag ? 1 : 0,
      final num number => number,
      final String text when text.length > FirebaseAnalyticsService.maxStringLength => text.substring(
        0,
        FirebaseAnalyticsService.maxStringLength,
      ),
      final Enum option => option.name,
      _ => value.toString(),
    },
};
