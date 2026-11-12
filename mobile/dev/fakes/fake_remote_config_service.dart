import 'dart:async';

import 'package:breakbite_core/data/services/services.dart';

class FakeRemoteConfigService implements RemoteConfigService {
  final values = Map<String, Object>.of(RemoteKeys.defaults);
  final _updates = StreamController<Set<String>>.broadcast();
  final fromConsole = <String>{};
  int fetches = 0;

  @override
  DateTime? lastFetchedAt;

  void publish(String key, Object value) {
    values[key] = value;
    fromConsole.add(key);
    lastFetchedAt = DateTime(2026, 11, 2, 10, fromConsole.length);
    _updates.add({key});
  }

  @override
  Future<void> fetchAndActivate() async {
    fetches++;
    lastFetchedAt = DateTime(2026, 11, 2, 9, fetches);
  }

  @override
  Stream<Set<String>> watchUpdates() => _updates.stream;

  @override
  int getInt(String key) => (values[key] as int?) ?? 0;

  @override
  bool getBool(String key) => (values[key] as bool?) ?? false;

  @override
  RemoteValueSource sourceOf(String key) =>
      fromConsole.contains(key) ? RemoteValueSource.console : RemoteValueSource.inApp;
}
