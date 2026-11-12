import 'package:breakbite_core/domain/models/order.dart';

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

  static const _announcementPrefix = 'ann_';

  static String idForAnnouncement(String announcementId) => '$_announcementPrefix$announcementId';

  /// Whether [id] was made by [idForAnnouncement].
  static bool isAnnouncementId(String id) => id.startsWith(_announcementPrefix);

  /// A message from the web admin (W05) rather than about one of the customer's orders.
  bool get isAnnouncement => isAnnouncementId(id);
}
