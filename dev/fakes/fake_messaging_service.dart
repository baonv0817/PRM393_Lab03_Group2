import 'dart:async';

import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/data/services/services.dart';

class FakeMessagingService implements MessagingService {
  final _foreground = StreamController<AppNotification>.broadcast();
  final _opened = StreamController<AppNotification>.broadcast();

  void emitForeground(AppNotification n) => _foreground.add(n);
  void emitOpened(AppNotification n) => _opened.add(n);

  @override
  Future<bool> requestPermission() async => true;

  @override
  Stream<AppNotification> foregroundMessages() => _foreground.stream;

  @override
  Stream<AppNotification> openedMessages() => _opened.stream;
}
