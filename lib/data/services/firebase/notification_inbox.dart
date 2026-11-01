import 'package:breakbite/data/firebase/firestore_helpers.dart';
import 'package:breakbite/domain/models/app_notification.dart';
import 'package:breakbite/domain/models/order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final _unsafeIdCharacters = RegExp('[^A-Za-z0-9_-]');

String notificationIdFor(RemoteMessage message, {DateTime? now}) {
  final data = message.data;
  final orderId = data['orderId'];
  final status = OrderStatus.values.asNameMap()[data['status']];
  if (orderId is String && orderId.isNotEmpty && status != null) return AppNotification.idForOrder(orderId, status);
  final announcementId = data['announcementId'];
  if (announcementId is String && announcementId.isNotEmpty) return AppNotification.idForAnnouncement(announcementId);
  final raw = message.messageId ?? '${(message.sentTime ?? now ?? DateTime.now()).millisecondsSinceEpoch}';
  return 'fcm_${raw.replaceAll(_unsafeIdCharacters, '_')}';
}

AppNotification notificationFromMessage(RemoteMessage message, {DateTime? now}) {
  final data = message.data;
  final orderId = data['orderId'];
  return AppNotification(
    id: notificationIdFor(message, now: now),
    title: message.notification?.title ?? _text(data['title']) ?? 'BreakBite',
    body: message.notification?.body ?? _text(data['body']) ?? '',
    receivedAt: message.sentTime ?? now ?? DateTime.now(),
    orderId: orderId is String && orderId.isNotEmpty ? orderId : null,
  );
}

String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;

Future<void> saveToInbox(FirebaseFirestore db, String uid, RemoteMessage message) async {
  final notification = notificationFromMessage(message);
  final ref = db.collection('users').doc(uid).collection('notifications').doc(notification.id);
  if ((await ref.get()).exists) return;
  await ref.set({
    'title': notification.title,
    'body': notification.body,
    'orderId': ?notification.orderId,
    'read': false,
    ...Stamp.created(),
  });
}
