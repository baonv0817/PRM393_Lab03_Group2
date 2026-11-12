import 'dart:convert';
import 'dart:io';

import 'package:breakbite/data/services/firebase/firebase_crash_service.dart';
import 'package:breakbite/data/services/firebase/notification_inbox.dart';
import 'package:breakbite_core/data/services/firebase/firebase_analytics_service.dart';
import 'package:breakbite_core/data/services/remote_config_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notifications from FCM', () {
    test('an order update gets the deterministic order id and opens that order', () {
      const message = RemoteMessage(
        messageId: '0:1',
        data: {'orderId': 'o6', 'status': 'ready'},
        notification: RemoteNotification(title: 'Đơn đã sẵn sàng', body: 'Mời bạn tới quầy'),
      );
      final n = notificationFromMessage(message);
      expect(n.id, 'o6_ready');
      expect(n.orderId, 'o6');
      expect(n.title, 'Đơn đã sẵn sàng');
    });

    test('an announcement uses its own id; a console test message gets a safe id from the message id', () {
      expect(notificationIdFor(const RemoteMessage(data: {'announcementId': 'a1'})), 'ann_a1');
      expect(
        notificationIdFor(const RemoteMessage(messageId: 'projects/p/messages/0:12%ab')),
        'fcm_projects_p_messages_0_12_ab',
      );
    });

    test('a data-only message still has a title and a body', () {
      final n = notificationFromMessage(const RemoteMessage(data: {'title': 'Khuyến mãi', 'body': 'Giảm 10K'}));
      expect(n.title, 'Khuyến mãi');
      expect(n.body, 'Giảm 10K');
      expect(n.orderId, isNull);
    });
  });

  test('analytics parameters only carry strings and numbers, strings capped at 100 characters', () {
    final params = analyticsParameters({'flag': true, 'count': 2, 'text': 'x' * 150});
    expect(params['flag'], 1);
    expect(params['count'], 2);
    expect((params['text']! as String).length, 100);
  });

  test('Crashlytics custom keys keep primitive values and stringify the rest', () {
    expect(crashKeyValue(3), 3);
    expect(crashKeyValue(true), true);
    expect(crashKeyValue(TestEnum.staff), 'staff');
    expect(crashKeyValue(const Duration(seconds: 1)), isA<String>());
  });

  test('in-app Remote Config defaults match the defaults file and the console template', () {
    final defaults =
        jsonDecode(File('../firebase/remote-config-defaults.json').readAsStringSync()) as Map<String, dynamic>;
    final template =
        jsonDecode(File('../firebase/remote-config-template.json').readAsStringSync()) as Map<String, dynamic>;
    final parameters = template['parameters'] as Map<String, dynamic>;
    expect(defaults.keys.toSet(), RemoteKeys.defaults.keys.toSet());
    expect(parameters.keys.toSet(), RemoteKeys.defaults.keys.toSet());
    for (final MapEntry(:key, :value) in RemoteKeys.defaults.entries) {
      expect(defaults[key], '$value', reason: key);
      final templateValue =
          ((parameters[key] as Map<String, dynamic>)['defaultValue'] as Map<String, dynamic>)['value'];
      expect(templateValue, '$value', reason: key);
    }
  });
}

enum TestEnum { staff }
