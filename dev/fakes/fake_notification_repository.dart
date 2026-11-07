import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';

/// Behaves like the Firestore version: an id is saved once, the newest notification comes first.
class FakeNotificationRepository implements NotificationRepository {
  final _inbox = <String, LiveValue<List<AppNotification>>>{};
  final _prefs = <String, LiveValue<NotificationPrefs>>{};
  AppException? failNextWrite;

  LiveValue<List<AppNotification>> _of(String uid) => _inbox.putIfAbsent(uid, () => LiveValue(const []));

  LiveValue<NotificationPrefs> _prefsOf(String uid) =>
      _prefs.putIfAbsent(uid, () => LiveValue(NotificationPrefs.defaults));

  List<AppNotification> of(String uid) => _of(uid).value;

  NotificationPrefs prefsOf(String uid) => _prefsOf(uid).value;

  @override
  Stream<List<AppNotification>> watch(String uid) => _of(uid).stream;

  @override
  Future<Result<void>> save(String uid, AppNotification notification) async {
    if (_failed() case final error?) return Result.error(error);
    if (of(uid).any((n) => n.id == notification.id)) return const Result.ok(null);
    _of(uid).set(_newestFirst([notification, ...of(uid)]));
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> markRead(String uid, String id) async {
    if (_failed() case final error?) return Result.error(error);
    _of(uid).set([for (final n in of(uid)) n.id == id ? _read(n) : n]);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> markAllRead(String uid) async {
    if (_failed() case final error?) return Result.error(error);
    _of(uid).set([for (final n in of(uid)) _read(n)]);
    return const Result.ok(null);
  }

  @override
  Stream<NotificationPrefs> watchPrefs(String uid) => _prefsOf(uid).stream;

  @override
  Future<Result<void>> setPrefs(String uid, NotificationPrefs prefs) async {
    if (_failed() case final error?) return Result.error(error);
    _prefsOf(uid).set(prefs);
    return const Result.ok(null);
  }

  AppException? _failed() {
    final error = failNextWrite;
    failNextWrite = null;
    return error;
  }

  static AppNotification _read(AppNotification n) =>
      AppNotification(id: n.id, title: n.title, body: n.body, receivedAt: n.receivedAt, orderId: n.orderId, read: true);

  static List<AppNotification> _newestFirst(List<AppNotification> list) =>
      [...list]..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
}
