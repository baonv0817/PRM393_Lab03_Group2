import 'dart:convert';
import 'dart:typed_data';

import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

class FakeReportFileService implements ReportFileService {
  final exported = <List<Order>>[];
  bool fail = false;

  @override
  Future<Result<GeneratedFile>> ordersSummary({
    required String customerName,
    required List<Order> orders,
    required DateTime now,
  }) async {
    if (fail) return const Result.error(ServiceException(message: 'Không tạo được tệp PDF.'));
    exported.add(orders);
    final text = '%PDF-fake $customerName ${orders.map((o) => o.id).join(',')}'.padRight(2048, ' ');
    return Result.ok(GeneratedFile(fileName: 'breakbite-don-hang.pdf', bytes: Uint8List.fromList(utf8.encode(text))));
  }
}
