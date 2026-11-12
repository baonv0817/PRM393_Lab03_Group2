import 'package:breakbite_core/data/services/report_file_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/text.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfReportFileService implements ReportFileService {
  PdfReportFileService({Future<ByteData> Function()? loadFont})
    : _loadFont = loadFont ?? (() => rootBundle.load('packages/breakbite_core/assets/fonts/Nunito.ttf'));

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

  @override
  Future<Result<GeneratedFile>> orderReceipt({
    required String customerName,
    required Order order,
    required DateTime now,
  }) async {
    try {
      final font = _font ??= pw.Font.ttf(await _loadFont());
      final document = pw.Document(title: 'BreakBite · Biên nhận đơn #${order.orderCode}', author: 'BreakBite');
      final pickup = order.pickupAt;
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: font),
          build: (context) => [
            pw.Text('BreakBite', style: const pw.TextStyle(fontSize: 22)),
            pw.SizedBox(height: 4),
            pw.Text('Biên nhận đơn #${order.orderCode}', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('Khách: $customerName · Quầy: ${order.kioskName}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text(
              'Đặt lúc ${formatDateTime(order.createdAt)} · ${orderStatusLabel(order.status)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
            if (pickup != null)
              pw.Text('Hẹn nhận lúc ${formatDateTime(pickup)}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Xuất lúc ${formatDateTime(now)}', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: const ['Món', 'SL', 'Đơn giá', 'Thành tiền'],
              data: [
                for (final item in order.items)
                  [
                    item.note.trim().isEmpty ? item.name : '${item.name}\nGhi chú: ${item.note.trim()}',
                    '${item.quantity}',
                    formatVnd(item.priceVnd),
                    formatVnd(item.lineTotalVnd),
                  ],
              ],
              cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Tạm tính: ${formatVnd(orderItemsTotalVnd(order))}'),
            if (order.discountVnd > 0)
              pw.Text(
                'Giảm${order.voucherCode == null ? '' : ' (mã ${order.voucherCode})'}: −${formatVnd(order.discountVnd)}',
              ),
            pw.Text('Tổng cộng: ${formatVnd(order.totalVnd)}', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('Thanh toán: ${paymentMethodLabel(order.paymentMethod)} · ${orderPaymentLabel(order)}'),
          ],
        ),
      );
      final bytes = await document.save();
      final code = slugify(order.orderCode);
      return Result.ok(
        GeneratedFile(
          fileName: 'breakbite-bien-nhan-${code.isEmpty ? 'don' : code}-${_fileStamp.format(now.toLocal())}.pdf',
          bytes: bytes,
        ),
      );
    } catch (error, stack) {
      return Result.error(ServiceException(message: 'Không tạo được tệp PDF.', cause: error, stackTrace: stack));
    }
  }
}
