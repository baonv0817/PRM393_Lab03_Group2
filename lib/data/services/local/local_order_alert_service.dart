import 'package:breakbite/data/services/order_alert_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// [OrderAlertService] with `flutter_local_notifications`: one high-importance notification with the default
/// sound and vibration. The same id every time, so a second order updates the notification instead of piling up,
/// but still rings again (`onlyAlertOnce` is off).
class LocalOrderAlertService implements OrderAlertService {
  LocalOrderAlertService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// 7100 is outside the break reminders' 7000–7099.
  static const _id = 7100;

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _ready;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'new_orders',
      'Đơn mới',
      channelDescription: 'Báo khi có khách đặt món ở kiosk của bạn',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
    ),
    iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
  );

  Future<bool> _init() => _ready ??= () async {
    try {
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
      debugPrint('New order alerts are not available: $error');
      return false;
    }
  }();

  @override
  Future<void> newOrders({required int count, String? orderCode}) async {
    if (!await _init()) return;
    try {
      await _plugin.show(
        id: _id,
        title: 'Có đơn mới',
        body: count == 1 && orderCode != null ? 'Đơn #$orderCode đang chờ nhận.' : '$count đơn mới đang chờ nhận.',
        notificationDetails: _details,
        payload: 'new_order',
      );
    } catch (error) {
      debugPrint('Could not show the new order alert: $error');
    }
  }
}
