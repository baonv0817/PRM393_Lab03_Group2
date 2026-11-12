import 'package:breakbite_core/data/services/services.dart';

import 'live_value.dart';

/// A network that tests and the dev app switch by hand ([online] = false is "airplane mode").
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({bool online = true}) : _online = LiveValue(online);

  final LiveValue<bool> _online;

  bool get online => _online.value;

  set online(bool value) => _online.set(value);

  @override
  Stream<bool> watchOnline() => _online.stream;

  @override
  Future<bool> check() async => _online.value;
}
