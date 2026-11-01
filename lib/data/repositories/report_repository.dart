import 'package:breakbite/data/services/storage_service.dart';
import 'package:breakbite/domain/models/report.dart';
import 'package:breakbite/utils/result.dart';

abstract interface class ReportRepository {
  static const listLimit = 10;

  Future<Result<Report>> save({
    required String uid,
    required String fileName,
    required UploadedFile file,
    String? orderId,
  });

  Stream<List<Report>> watchMine(String uid, {int limit = listLimit});
}
