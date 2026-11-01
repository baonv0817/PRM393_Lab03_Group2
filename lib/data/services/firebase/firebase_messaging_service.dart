import 'dart:async';

import 'package:breakbite/data/firebase/firestore_helpers.dart';
import 'package:breakbite/data/services/firebase/notification_inbox.dart';
import 'package:breakbite/data/services/messaging_service.dart';
import 'package:breakbite/domain/models/app_notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FirebaseMessagingService implements MessagingService {
  FirebaseMessagingService({required this._messaging, required this._db});

  static const maxTokens = 5;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  String? _uid;
  StreamSubscription<RemoteMessage>? _inbox;
  StreamSubscription<String>? _tokenRefresh;

  @override
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  @override
  Stream<AppNotification> foregroundMessages() => FirebaseMessaging.onMessage.map(notificationFromMessage);

  @override
  Stream<AppNotification> openedMessages() async* {
    RemoteMessage? initial;
    try {
      initial = await _messaging.getInitialMessage();
    } catch (error) {
      debugPrint('Could not read the notification that opened the app: $error');
    }
    if (initial != null) {
      await _save(initial);
      yield notificationFromMessage(initial);
    }
    yield* FirebaseMessaging.onMessageOpenedApp.asyncMap((message) async {
      await _save(message);
      return notificationFromMessage(message);
    });
  }

  @override
  Future<String?> currentToken() async {
    try {
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('FCM token is not available: $error');
      return null;
    }
  }

  @override
  Future<void> attachUser(String uid) async {
    _uid = uid;
    _inbox ??= FirebaseMessaging.onMessage.listen((message) => unawaited(_save(message)));
    // ignore: deprecated_member_use
    _tokenRefresh ??= _messaging.onTokenRefresh.listen((token) {
      final current = _uid;
      if (current != null) unawaited(_storeToken(current, token));
    });
    final token = await currentToken();
    if (token != null) await _storeToken(uid, token);
  }

  @override
  Future<void> detachUser(String uid) async {
    _uid = null;
    await _inbox?.cancel();
    await _tokenRefresh?.cancel();
    _inbox = null;
    _tokenRefresh = null;
    final token = await currentToken();
    if (token == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
        ...Stamp.updated(),
      });
    } catch (error) {
      debugPrint('FCM token was not removed: $error');
    }
  }

  Future<void> _storeToken(String uid, String token) async {
    final ref = _db.collection('users').doc(uid);
    try {
      await _db.runTransaction<void>((tx) async {
        final snapshot = await tx.get(ref);
        final data = snapshot.data();
        if (data == null) return;
        final tokens = [
          for (final value in data['fcmTokens'] is List ? data['fcmTokens'] as List : const <Object>[])
            if (value is String) value,
        ];
        if (tokens.contains(token)) return;
        final next = [...tokens, token];
        tx.update(ref, {
          'fcmTokens': next.sublist(next.length > maxTokens ? next.length - maxTokens : 0),
          ...Stamp.updated(),
        });
      });
    } catch (error) {
      debugPrint('FCM token was not saved: $error');
    }
  }

  Future<void> _save(RemoteMessage message) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await saveToInbox(_db, uid, message);
    } catch (error) {
      debugPrint('Notification was not saved to the inbox: $error');
    }
  }
}
