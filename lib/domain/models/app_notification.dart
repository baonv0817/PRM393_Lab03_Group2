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

  /// Màn liên quan khi chạm vào thông báo (nếu có).
  final String? orderId;
  final bool read;
}
