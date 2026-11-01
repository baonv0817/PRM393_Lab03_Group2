import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';

class FakeReportRepository implements ReportRepository {
  final _reports = LiveValue<List<Report>>(const []);
  var _seq = 0;
  var _clock = DateTime(2026, 11, 2, 10);
  AppException? failNextSave;

  List<Report> get all => _reports.value;

  @override
  Future<Result<Report>> save({
    required String uid,
    required String fileName,
    required UploadedFile file,
    String? orderId,
  }) async {
    if (failNextSave case final error?) {
      failNextSave = null;
      return Result.error(error);
    }
    _clock = _clock.add(const Duration(minutes: 1));
    final report = Report(
      id: 'r${++_seq}',
      uid: uid,
      fileName: fileName,
      url: file.url,
      publicId: file.publicId,
      sizeKb: (file.sizeBytes / 1024).ceil(),
      createdAt: _clock,
      orderId: orderId,
    );
    _reports.set([report, ..._reports.value]);
    return Result.ok(report);
  }

  @override
  Stream<List<Report>> watchMine(String uid, {int limit = ReportRepository.listLimit}) =>
      _reports.stream.map((reports) => reports.where((r) => r.uid == uid).take(limit).toList());
}
