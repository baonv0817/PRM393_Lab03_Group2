import 'dart:async';

import 'package:breakbite/data/services/remote_config_service.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class FirebaseRemoteConfigService implements RemoteConfigService {
  FirebaseRemoteConfigService(this._config, {this.minimumFetchInterval = const Duration(hours: 1)});

  final FirebaseRemoteConfig _config;
  final Duration minimumFetchInterval;
  final _changes = StreamController<Set<String>>.broadcast();
  StreamSubscription<RemoteConfigUpdate>? _realtime;

  Future<void> initialize() async {
    try {
      await _config.setConfigSettings(
        RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: minimumFetchInterval),
      );
      await _config.setDefaults(RemoteKeys.defaults);
      await _config.activate();
    } catch (error) {
      debugPrint('Remote Config keeps the in-app defaults: $error');
    }
    _realtime ??= _config.onConfigUpdated.listen((update) async {
      try {
        await _config.activate();
        _changes.add(update.updatedKeys);
      } catch (error) {
        debugPrint('Remote Config update was not applied: $error');
      }
    }, onError: (Object error) => debugPrint('Remote Config realtime updates stopped: $error'));
  }

  @override
  Future<void> fetchAndActivate() async {
    try {
      if (await _config.fetchAndActivate()) _changes.add(RemoteKeys.defaults.keys.toSet());
    } catch (error) {
      debugPrint('Remote Config fetch failed, keeping the last values: $error');
    }
  }

  @override
  Stream<Set<String>> watchUpdates() => _changes.stream;

  @override
  int getInt(String key) {
    try {
      return _config.getInt(key);
    } catch (_) {
      return switch (RemoteKeys.defaults[key]) {
        final int value => value,
        _ => 0,
      };
    }
  }

  @override
  bool getBool(String key) {
    try {
      return _config.getBool(key);
    } catch (_) {
      return switch (RemoteKeys.defaults[key]) {
        final bool value => value,
        _ => false,
      };
    }
  }

  Future<void> dispose() async {
    await _realtime?.cancel();
    await _changes.close();
  }
}
