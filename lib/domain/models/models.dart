/// Mô hình dữ liệu thuần (không phụ thuộc Flutter hay Firebase), mỗi model một tệp.
/// Ánh xạ với collection Firestore trong `docs/data-model.md`: tên trường giữ nguyên ở đó;
/// việc đổi `Timestamp` sang `DateTime` làm ở `lib/data/`.
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
