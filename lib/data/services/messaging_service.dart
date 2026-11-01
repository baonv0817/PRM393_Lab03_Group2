import 'package:breakbite/domain/models/app_notification.dart';

abstract interface class MessagingService {
  Future<bool> requestPermission();

  Stream<AppNotification> foregroundMessages();

  Stream<AppNotification> openedMessages();

  Future<String?> currentToken();

  Future<void> attachUser(String uid);

  Future<void> detachUser(String uid);
}
