import 'package:breakbite/domain/models/app_notification.dart';

abstract interface class MessagingService {
  /// Requests notification permission (Android 13+). Returns `true` if granted.
  Future<bool> requestPermission();

  /// Notifications received while the app is in the foreground.
  Stream<AppNotification> foregroundMessages();

  /// The user tapped a notification to open the app (from background or terminated).
  Stream<AppNotification> openedMessages();
}
