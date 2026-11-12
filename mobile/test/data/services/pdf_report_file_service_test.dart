import 'dart:io';
import 'dart:typed_data';

import 'package:breakbite/data/services/pdf/pdf_report_file_service.dart';
import 'package:breakbite_core/data/services/report_file_service.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = PdfReportFileService(
    loadFont: () async => ByteData.sublistView(File('../packages/core/assets/fonts/Nunito.ttf').readAsBytesSync()),
  );
  final now = DateTime(2026, 11, 2, 10, 20);

  Order order(String id, OrderStatus status, int total) => Order(
    id: id,
    uid: 'u1',
    orderCode: id.toUpperCase(),
    kioskId: 'q9-t2',
    kioskName: 'Kiosk Q9 · Tầng 2',
    items: [CartItem(itemId: 'q9-t2-tacos', name: 'Combo Tacos Bò Phô Mai', priceVnd: total)],
    totalVnd: total,
    paymentMethod: PaymentMethod.cash,
    status: status,
    createdAt: now.subtract(const Duration(days: 1)),
  );

  test('the orders summary is a PDF named after the export time', () async {
    final result = await service.ordersSummary(
      customerName: 'Nguyễn Minh Quân',
      orders: [order('a1b2c3', OrderStatus.delivered, 39000), order('d4e5f6', OrderStatus.cancelled, 20000)],
      now: now,
    );
    final file = (result as Ok<GeneratedFile>).value;
    expect(String.fromCharCodes(file.bytes.take(5)), '%PDF-');
    expect(file.fileName, 'breakbite-don-hang-20261102-1020.pdf');
    expect(file.sizeKb, greaterThan(0));
  });

  test('a customer without orders still gets a valid PDF', () async {
    final result = await service.ordersSummary(customerName: 'Khách', orders: const [], now: now);
    expect(String.fromCharCodes((result as Ok<GeneratedFile>).value.bytes.take(5)), '%PDF-');
  });

  group('order receipt', () {
    final discounted = Order(
      id: 'a1b2c3',
      uid: 'u1',
      orderCode: 'A1B2C3',
      kioskId: 'q9-t2',
      kioskName: 'Kiosk Q9 · Tầng 2',
      items: const [
        CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000, quantity: 2, note: 'Ít cay'),
        CartItem(itemId: 'm2', name: 'Trà đào', priceVnd: 25000),
      ],
      totalVnd: 93000,
      discountVnd: 10000,
      voucherCode: 'BBSTUDENT',
      paymentMethod: PaymentMethod.momo,
      status: OrderStatus.delivered,
      createdAt: now.subtract(const Duration(hours: 1)),
      pickupAt: now,
    );

    test('is a PDF named after the order code and the export time', () async {
      final result = await service.orderReceipt(customerName: 'Nguyễn Minh Quân', order: discounted, now: now);
      final file = (result as Ok<GeneratedFile>).value;
      expect(String.fromCharCodes(file.bytes.take(5)), '%PDF-');
      expect(file.fileName, 'breakbite-bien-nhan-a1b2c3-20261102-1020.pdf');
      expect(file.sizeKb, greaterThan(0));
    });

    test('an order without a voucher, note or pickup time still gives a valid PDF', () async {
      final plain = order('d4e5f6', OrderStatus.cancelled, 20000);
      final result = await service.orderReceipt(customerName: 'Khách', order: plain, now: now);
      expect(String.fromCharCodes((result as Ok<GeneratedFile>).value.bytes.take(5)), '%PDF-');
    });

    test('a font that cannot load gives a readable error instead of throwing', () async {
      final broken = PdfReportFileService(loadFont: () async => throw const FileSystemException('missing'));
      final result = await broken.orderReceipt(customerName: 'Khách', order: discounted, now: now);
      expect((result as Err<GeneratedFile>).error.message, 'Không tạo được tệp PDF.');
    });
  });

  test('a font that cannot load gives a readable error instead of throwing', () async {
    final broken = PdfReportFileService(loadFont: () async => throw const FileSystemException('missing'));
    final result = await broken.ordersSummary(customerName: 'Khách', orders: const [], now: now);
    expect((result as Err<GeneratedFile>).error.message, 'Không tạo được tệp PDF.');
  });
}
