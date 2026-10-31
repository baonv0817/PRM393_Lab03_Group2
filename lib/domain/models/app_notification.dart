class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.orderId,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;

  /// Related screen to open when the notification is tapped (if any).
  final String? orderId;
  final bool read;
}
