/// Plain data models (no Flutter or Firebase dependency), one model per file.
/// Mapped to the Firestore collections in `docs/data-model.md`: field names are kept as defined there;
/// converting `Timestamp` to `DateTime` happens in `lib/data/`.
library;

export 'app_notification.dart';
export 'app_user.dart';
export 'cart_item.dart';
export 'incident.dart';
export 'kiosk.dart';
export 'menu_item.dart';
export 'order.dart';
export 'pickup_slot.dart';
export 'review.dart';
export 'voucher.dart';
