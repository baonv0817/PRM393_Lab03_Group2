import 'dart:async';

import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/models/models.dart';

class FakeMessagingService implements MessagingService {
  final _foreground = StreamController<AppNotification>.broadcast();
  final _opened = StreamController<AppNotification>.broadcast();
  final attached = <String>[];
  final detached = <String>[];
  int permissionRequests = 0;
  bool grantPermission = true;

  void emitForeground(AppNotification n) => _foreground.add(n);
  void emitOpened(AppNotification n) => _opened.add(n);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

  @override
  Stream<AppNotification> foregroundMessages() => _foreground.stream;

  @override
  Stream<AppNotification> openedMessages() => _opened.stream;

  @override
  Future<String?> currentToken() async => 'fake-fcm-token';

  @override
  Future<void> attachUser(String uid) async => attached.add(uid);

  @override
  Future<void> detachUser(String uid) async => detached.add(uid);
}
