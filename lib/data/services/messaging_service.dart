import '../../domain/models/app_notification.dart';

abstract interface class MessagingService {
  /// Xin quyền thông báo (Android 13+). Trả `true` nếu được cấp.
  Future<bool> requestPermission();

  /// Thông báo nhận khi app ở nền trước.
  Stream<AppNotification> foregroundMessages();

  /// Người dùng chạm vào thông báo để mở app (nền hoặc đã tắt).
  Stream<AppNotification> openedMessages();
}
