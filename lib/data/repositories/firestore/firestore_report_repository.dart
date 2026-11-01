import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/data/firebase/firestore_helpers.dart';
import 'package:breakbite/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite/data/repositories/report_repository.dart';
import 'package:breakbite/data/services/storage_service.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreReportRepository implements ReportRepository {
  FirestoreReportRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const maxSizeKb = 5120;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  CollectionReference<Json> get _reports => _db.collection('reports');

  @override
  Future<Result<Report>> save({
    required String uid,
    required String fileName,
    required UploadedFile file,
    String? orderId,
  }) => guard(() async {
    final sizeKb = (file.sizeBytes / 1024).ceil();
    if (uid.isEmpty) throw const PermissionDeniedException();
    if (sizeKb < 1 || sizeKb > maxSizeKb) throw const ValidationException('Tệp phải từ 1 KB đến 5 MB.');
    if (!file.url.startsWith('https://')) throw const ValidationException('Đường dẫn tệp không hợp lệ.');
    final ref = _reports.doc();
    await ref.set({
      'uid': uid,
      'fileName': fileName,
      'url': file.url,
      'publicId': file.publicId,
      'sizeKb': sizeKb,
      'orderId': ?orderId,
      ...Stamp.created(),
    });
    return Report(
      id: ref.id,
      uid: uid,
      fileName: fileName,
      url: file.url,
      publicId: file.publicId,
      sizeKb: sizeKb,
      createdAt: _clock(),
      orderId: orderId,
    );
  });

  @override
  Stream<List<Report>> watchMine(String uid, {int limit = ReportRepository.listLimit}) => guardStream(
    _reports
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) reportFromData(doc.id, doc.data(), now: _clock())]),
  );
}
