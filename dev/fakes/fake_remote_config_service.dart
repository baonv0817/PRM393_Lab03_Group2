import 'dart:async';

import 'package:breakbite/data/services/services.dart';

class FakeRemoteConfigService implements RemoteConfigService {
  final values = Map<String, Object>.of(RemoteKeys.defaults);
  final _updates = StreamController<Set<String>>.broadcast();

  void publish(String key, Object value) {
    values[key] = value;
    _updates.add({key});
  }

  @override
  Future<void> fetchAndActivate() async {}

  @override
  Stream<Set<String>> watchUpdates() => _updates.stream;

  @override
  int getInt(String key) => (values[key] as int?) ?? 0;

  @override
  bool getBool(String key) => (values[key] as bool?) ?? false;
}
