import 'package:breakbite/data/services/services.dart';

class FakeRemoteConfigService implements RemoteConfigService {
  final values = <String, Object>{
    RemoteKeys.quickItemsLimit: 5,
    RemoteKeys.promoBannerEnabled: true,
    RemoteKeys.pickupSlotEnabled: true,
  };

  @override
  Future<void> fetchAndActivate() async {}

  @override
  int getInt(String key) => (values[key] as int?) ?? 0;

  @override
  bool getBool(String key) => (values[key] as bool?) ?? false;
}
