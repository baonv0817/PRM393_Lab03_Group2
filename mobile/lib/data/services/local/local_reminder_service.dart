import 'package:breakbite_core/data/services/reminder_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// [ReminderService] with `flutter_local_notifications`. Times are scheduled as absolute instants (UTC), so
/// the phone's time zone does not matter. Android may deliver them a few minutes late to save battery
/// (inexact alarms need no extra permission), which is fine for a "10 minutes before" reminder.
class LocalReminderService implements ReminderService {
  LocalReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Ids 7000–7099 are the break reminders, so cancelling them leaves other notifications alone.
  static const _firstId = 7000;
  static const _maxReminders = 100;

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _ready;
  int _scheduled = 0;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'break_reminder',
      'Nhắc trước giờ nghỉ',
      channelDescription: 'Nhắc đặt món trước giờ nghỉ 10 phút',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<bool> _init() => _ready ??= () async {
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return true;
    } catch (error) {
      debugPrint('Break reminders are not available: $error');
      return false;
    }
  }();

  @override
  Future<void> scheduleBreakReminders(List<BreakReminder> reminders) async {
    if (!await _init()) return;
    await cancelBreakReminders();
    var id = _firstId;
    for (final reminder in reminders.take(_maxReminders)) {
      try {
        await _plugin.zonedSchedule(
          id: id++,
          title: 'Sắp tới giờ nghỉ ${_time(reminder.breakStart)}',
          body: 'Đặt món ngay để nhận khi vừa ra chơi.',
          scheduledDate: tz.TZDateTime.from(reminder.at.toUtc(), tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'break_reminder',
        );
      } catch (error) {
        debugPrint('Could not schedule a break reminder: $error');
      }
    }
    _scheduled = id - _firstId;
  }

  @override
  Future<void> cancelBreakReminders() async {
    if (!await _init()) return;
    final count = _scheduled == 0 ? _maxReminders : _scheduled;
    for (var id = _firstId; id < _firstId + count; id++) {
      try {
        await _plugin.cancel(id: id);
      } catch (error) {
        debugPrint('Could not cancel a break reminder: $error');
      }
    }
    _scheduled = 0;
  }

  static String _time(DateTime t) {
    final local = t.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
