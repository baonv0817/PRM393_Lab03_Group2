abstract final class RemoteKeys {
  static const quickItemsLimit = 'quick_items_limit';
  static const promoBannerEnabled = 'promo_banner_enabled';
  static const pickupSlotEnabled = 'pickup_slot_enabled';

  static const defaults = <String, Object>{quickItemsLimit: 5, promoBannerEnabled: true, pickupSlotEnabled: true};
}

abstract interface class RemoteConfigService {
  Future<void> fetchAndActivate();

  Stream<Set<String>> watchUpdates();

  int getInt(String key);

  bool getBool(String key);
}
