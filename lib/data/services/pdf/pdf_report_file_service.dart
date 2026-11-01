import 'package:breakbite/data/services/report_file_service.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/order.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfReportFileService implements ReportFileService {
  PdfReportFileService({Future<ByteData> Function()? loadFont})
    : _loadFont = loadFont ?? (() => rootBundle.load('assets/fonts/Nunito.ttf'));

  static final _fileStamp = DateFormat('yyyyMMdd-HHmm');

  final Future<ByteData> Function() _loadFont;
  pw.Font? _font;

  @override
  Future<Result<GeneratedFile>> ordersSummary({
    required String customerName,
    required List<Order> orders,
    required DateTime now,
  }) async {
    try {
      final font = _font ??= pw.Font.ttf(await _loadFont());
      final counted = orders.where((o) => o.status != OrderStatus.cancelled);
      final total = counted.fold<int>(0, (sum, o) => sum + o.totalVnd);
      final document = pw.Document(title: 'BreakBite · Tóm tắt đơn hàng', author: 'BreakBite');
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: font),
          build: (context) => [
            pw.Text('BreakBite', style: const pw.TextStyle(fontSize: 22)),
            pw.SizedBox(height: 4),
            pw.Text('Tóm tắt đơn hàng của $customerName', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('Xuất lúc ${formatDateTime(now)}', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
            if (orders.isEmpty)
              pw.Text('Chưa có đơn hàng nào.')
            else
              pw.TableHelper.fromTextArray(
                headers: const ['Mã đơn', 'Thời gian', 'Quầy', 'Món', 'Trạng thái', 'Tổng'],
                data: [
                  for (final order in orders)
                    [
                      order.orderCode,
                      formatDateTime(order.createdAt),
                      order.kioskName,
                      order.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
                      orderStatusLabel(order.status),
                      formatVnd(order.totalVnd),
                    ],
                ],
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerStyle: const pw.TextStyle(fontSize: 10),
              ),
            pw.SizedBox(height: 12),
            pw.Text('${orders.length} đơn · ${counted.length} đơn không huỷ · Tổng ${formatVnd(total)}'),
          ],
        ),
      );
      final bytes = await document.save();
      return Result.ok(
        GeneratedFile(fileName: 'breakbite-don-hang-${_fileStamp.format(now.toLocal())}.pdf', bytes: bytes),
      );
    } catch (error, stack) {
      return Result.error(ServiceException(message: 'Không tạo được tệp PDF.', cause: error, stackTrace: stack));
    }
  }
}
