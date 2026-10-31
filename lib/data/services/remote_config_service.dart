/// Remote Config keys (matching `firebase/remote-config-defaults.json`).
abstract final class RemoteKeys {
  static const quickItemsLimit = 'quick_items_limit';
  static const promoBannerEnabled = 'promo_banner_enabled';
  static const pickupSlotEnabled = 'pickup_slot_enabled';
}

abstract interface class RemoteConfigService {
  Future<void> fetchAndActivate();
  int getInt(String key);
  bool getBool(String key);
}
