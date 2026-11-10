import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/data/firebase/firestore_helpers.dart';
import 'package:breakbite/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite/data/repositories/notification_repository.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

/// `users/{uid}/notifications/{id}` and `users/{uid}.notificationPrefs`. The rules let only the owner read
/// and write both. The id of a notification about an order is `{orderId}_{status}` (written with `set`), so
/// the same change seen twice stays one notification.
class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Firestore refuses a write batch of more than 500 writes; this leaves room to spare.
  static const batchSize = 400;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  DocumentReference<Json> _user(String uid) => _db.collection('users').doc(uid);

  CollectionReference<Json> _inbox(String uid) => _user(uid).collection('notifications');

  @override
  Stream<List<AppNotification>> watch(String uid) => guardStream(
    _inbox(uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) notificationFromData(doc.id, doc.data(), now: _clock())]),
  );

  @override
  Future<Result<void>> save(String uid, AppNotification notification) => guard(() async {
    if (uid.isEmpty) throw const PermissionDeniedException();
    final ref = _inbox(uid).doc(notification.id);
    if ((await ref.get()).exists) return;
    await ref.set({
      'title': notification.title,
      'body': notification.body,
      'orderId': ?notification.orderId,
      'read': false,
      ...Stamp.created(),
    });
  });

  @override
  Future<Result<void>> markRead(String uid, String id) => guard(() async {
    if (uid.isEmpty) throw const PermissionDeniedException();
    await _inbox(uid).doc(id).update({'read': true, ...Stamp.updated()});
  });

  @override
  Future<Result<void>> markAllRead(String uid) => guard(() async {
    if (uid.isEmpty) throw const PermissionDeniedException();
    final unread = await _inbox(uid).where('read', isEqualTo: false).get();
    // A write batch holds at most 500 writes, so a long list is marked in several batches.
    for (var start = 0; start < unread.docs.length; start += batchSize) {
      final batch = _db.batch();
      for (final doc in unread.docs.skip(start).take(batchSize)) {
        batch.update(doc.reference, {'read': true, ...Stamp.updated()});
      }
      await batch.commit();
    }
  });

  @override
  Stream<NotificationPrefs> watchPrefs(String uid) => guardStream(
    _user(uid).snapshots().map((snapshot) => NotificationPrefs.fromMap(snapshot.data()?['notificationPrefs'])),
  );

  @override
  Future<Result<void>> setPrefs(String uid, NotificationPrefs prefs) => guard(() async {
    if (uid.isEmpty) throw const PermissionDeniedException();
    await _user(uid).update({'notificationPrefs': prefs.toMap(), ...Stamp.updated()});
  });
}

AppNotification notificationFromData(String id, Json data, {required DateTime now}) => AppNotification(
  id: id,
  title: data['title'] as String? ?? '',
  body: data['body'] as String? ?? '',
  // The server time is empty for a moment after a local write; the notification is from now then.
  receivedAt: readDateOr(data['createdAt'], now),
  orderId: data['orderId'] as String?,
  read: data['read'] as bool? ?? false,
);
