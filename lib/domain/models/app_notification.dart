import 'package:breakbite/domain/models/order.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.orderId,
    this.read = false,
  });

  /// Use [idForOrder] or [idForAnnouncement] and write with `set`: the same event seen on two devices,
  /// or twice on one, then stays a single notification.
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;

  /// Related screen to open when the notification is tapped (if any).
  final String? orderId;
  final bool read;

  static String idForOrder(String orderId, OrderStatus status) => '${orderId}_${status.name}';

  static String idForAnnouncement(String announcementId) => 'ann_$announcementId';
}
