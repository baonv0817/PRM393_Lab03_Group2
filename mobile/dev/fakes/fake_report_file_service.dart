import 'dart:convert';
import 'dart:typed_data';

import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

class FakeReportFileService implements ReportFileService {
  final exported = <List<Order>>[];
  final receipts = <Order>[];
  bool fail = false;

  @override
  Future<Result<GeneratedFile>> orderReceipt({
    required String customerName,
    required Order order,
    required DateTime now,
  }) async {
    if (fail) return const Result.error(ServiceException(message: 'Không tạo được tệp PDF.'));
    receipts.add(order);
    final text = '%PDF-fake receipt $customerName ${order.id}'.padRight(2048, ' ');
    return Result.ok(
      GeneratedFile(
        fileName: 'breakbite-bien-nhan-${order.id.toLowerCase()}.pdf',
        bytes: Uint8List.fromList(utf8.encode(text)),
      ),
    );
  }

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
