import 'dart:typed_data';

import 'package:breakbite/domain/models/order.dart';
import 'package:breakbite/utils/result.dart';

class GeneratedFile {
  const GeneratedFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  int get sizeKb => (bytes.length / 1024).ceil();
}

abstract interface class ReportFileService {
  Future<Result<GeneratedFile>> ordersSummary({
    required String customerName,
    required List<Order> orders,
    required DateTime now,
  });

  /// A receipt for the single order the customer is viewing (S12).
  Future<Result<GeneratedFile>> orderReceipt({
    required String customerName,
    required Order order,
    required DateTime now,
  });
}
