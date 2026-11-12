import 'package:breakbite_core/domain/models/app_notification.dart';
import 'package:breakbite_core/domain/models/notification_prefs.dart';
import 'package:breakbite_core/utils/result.dart';

/// The notification inbox of S19 (`users/{uid}/notifications`) and the switches of S18
/// (`users/{uid}.notificationPrefs`).
abstract interface class NotificationRepository {
  /// The inbox, newest first. Emits again after every change.
  Stream<List<AppNotification>> watch(String uid);

  /// Puts [notification] in the inbox unless one with the same id is already there, so the same order change
  /// seen twice (or on two phones) stays one notification.
  Future<Result<void>> save(String uid, AppNotification notification);

  Future<Result<void>> markRead(String uid, String id);

  Future<Result<void>> markAllRead(String uid);

  /// The S18 switches; the defaults until the customer changes one.
  Stream<NotificationPrefs> watchPrefs(String uid);

  Future<Result<void>> setPrefs(String uid, NotificationPrefs prefs);
}
