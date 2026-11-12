import 'dart:async';

import 'package:breakbite_core/data/repositories/announcement_repository.dart';
import 'package:breakbite_core/data/repositories/notification_repository.dart';
import 'package:breakbite_core/domain/models/announcement.dart';
import 'package:breakbite_core/domain/models/app_notification.dart';
import 'package:breakbite_core/domain/models/notification_prefs.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/foundation.dart';

/// The customer's inbox (S19, and the dot on the Home bell): their own notifications from
/// `users/{uid}/notifications` plus the announcements the web admin published (W05), live.
///
/// An announcement is shown while it is published and reaches the kiosk the customer chose
/// ([Announcement.reaches]); archiving it on the web removes it from the inbox at once. Whether it was read is
/// kept in the customer's own inbox under [AppNotification.idForAnnouncement], so it survives a restart and
/// another phone. Everything else is passed to the wrapped repository unchanged.
class AnnouncementInboxRepository implements NotificationRepository {
  AnnouncementInboxRepository({
    required this._notifications,
    required this._announcements,
    required this._selectedKioskId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final NotificationRepository _notifications;
  final AnnouncementRepository _announcements;
  final Stream<String?> Function() _selectedKioskId;
  final DateTime Function() _clock;

  /// The announcements each customer saw last, so [markRead] and [markAllRead] can store them.
  final _shown = <String, Map<String, AppNotification>>{};

  /// [own] (the inbox documents) with every announcement in [published] that reaches [kioskId], newest first.
  /// The inbox documents of announcements only carry the read flag; the text always comes from the announcement.
  static List<AppNotification> merge(
    List<AppNotification> own,
    List<Announcement> published,
    String? kioskId, {
    required DateTime now,
  }) {
    final read = {
      for (final n in own)
        if (n.isAnnouncement && n.read) n.id,
    };
    return [
      for (final n in own)
        if (!n.isAnnouncement) n,
      for (final a in published)
        if (a.reaches(kioskId))
          AppNotification(
            id: AppNotification.idForAnnouncement(a.id),
            title: a.title,
            body: a.body,
            receivedAt: a.publishedAt ?? a.createdAt ?? now,
            read: read.contains(AppNotification.idForAnnouncement(a.id)),
          ),
    ]..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
  }

  @override
  Stream<List<AppNotification>> watch(String uid) {
    late final StreamController<List<AppNotification>> controller;
    final subs = <StreamSubscription<Object?>>[];
    List<AppNotification>? own;
    var published = const <Announcement>[];
    String? kioskId;

    void emit() {
      // Nothing until the customer's own inbox has loaded, so the screen keeps its loading state.
      final mine = own;
      if (mine == null || controller.isClosed) return;
      final merged = merge(mine, published, kioskId, now: _clock());
      _shown[uid] = {
        for (final n in merged)
          if (n.isAnnouncement) n.id: n,
      };
      controller.add(merged);
    }

    controller = StreamController<List<AppNotification>>(
      onListen: () {
        subs
          ..add(
            _notifications.watch(uid).listen((list) {
              own = list;
              emit();
            }, onError: controller.addError),
          )
          ..add(
            _announcements.watchPublished().listen(
              (list) {
                published = list;
                emit();
              },
              // Order notifications still work when announcements cannot be read.
              onError: (Object error) {
                debugPrint('Announcements are not in the inbox: $error');
                published = const [];
                emit();
              },
            ),
          )
          ..add(
            _selectedKioskId().listen((id) {
              kioskId = id;
              emit();
            }, onError: (Object _) {}),
          );
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
        subs.clear();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<Result<void>> markRead(String uid, String id) async {
    if (!AppNotification.isAnnouncementId(id)) return _notifications.markRead(uid, id);
    final stored = await _store(uid, id);
    if (stored case Err()) return stored;
    return _notifications.markRead(uid, id);
  }

  @override
  Future<Result<void>> markAllRead(String uid) async {
    // The missing inbox documents are written side by side, not one after another (CR-F07).
    final unread = [
      for (final n in (_shown[uid] ?? const <String, AppNotification>{}).values)
        if (!n.read) n.id,
    ];
    final stored = await Future.wait([for (final id in unread) _store(uid, id)]);
    for (final result in stored) {
      if (result case Err()) return result;
    }
    return _notifications.markAllRead(uid);
  }

  /// Creates the inbox document of an announcement (unread) if it is not there yet; `save` skips existing ones.
  Future<Result<void>> _store(String uid, String id) {
    final shown = _shown[uid]?[id];
    return _notifications.save(
      uid,
      AppNotification(id: id, title: shown?.title ?? '', body: shown?.body ?? '', receivedAt: _clock()),
    );
  }

  @override
  Future<Result<void>> save(String uid, AppNotification notification) => _notifications.save(uid, notification);

  @override
  Stream<NotificationPrefs> watchPrefs(String uid) => _notifications.watchPrefs(uid);

  @override
  Future<Result<void>> setPrefs(String uid, NotificationPrefs prefs) => _notifications.setPrefs(uid, prefs);
}
