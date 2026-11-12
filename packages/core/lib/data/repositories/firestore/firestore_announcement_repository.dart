import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/announcement_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/announcement.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAnnouncementRepository implements AnnouncementRepository {
  FirestoreAnnouncementRepository(this._db);

  /// The inbox shows at most this many; older ones stay in Firestore.
  static const inboxLimit = 50;

  final FirebaseFirestore _db;

  CollectionReference<Json> get _all => _db.collection('announcements');

  @override
  Stream<List<Announcement>> watchAll() => guardStream(
    _all.orderBy('createdAt', descending: true).snapshots().map((s) => [for (final d in s.docs) _fromDoc(d)]),
  );

  @override
  Stream<List<Announcement>> watchPublished() => guardStream(
    _all
        .where('status', isEqualTo: AnnouncementStatus.published.name)
        .orderBy('publishedAt', descending: true)
        .limit(inboxLimit)
        .snapshots()
        .map((s) => [for (final d in s.docs) _fromDoc(d)]),
  );

  @override
  Future<Result<String>> create({
    required String title,
    required String body,
    required String createdBy,
    required bool publish,
    String? kioskId,
  }) async {
    final problem = Announcement.problemWith(title: title, body: body);
    if (problem != null) return Result.error(ValidationException(problem));
    return guard(() async {
      final ref = _all.doc();
      await ref.set({
        'title': title.trim(),
        'body': body.trim(),
        'status': (publish ? AnnouncementStatus.published : AnnouncementStatus.draft).name,
        'createdBy': createdBy,
        if (kioskId != null && kioskId.isNotEmpty) 'kioskId': kioskId,
        if (publish) 'publishedAt': FieldValue.serverTimestamp(),
        ...Stamp.created(),
      });
      return ref.id;
    });
  }

  @override
  Future<Result<void>> setStatus(String id, AnnouncementStatus status) => guard(
    () => _all.doc(id).update({
      'status': status.name,
      if (status == AnnouncementStatus.published) 'publishedAt': FieldValue.serverTimestamp(),
      ...Stamp.updated(),
    }),
  );

  Announcement _fromDoc(DocumentSnapshot<Json> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Announcement(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      status: readEnum(AnnouncementStatus.values, data['status'], AnnouncementStatus.draft),
      createdBy: data['createdBy'] as String? ?? '',
      kioskId: data['kioskId'] as String?,
      createdAt: readDate(data['createdAt']),
      publishedAt: readDate(data['publishedAt']),
    );
  }
}
