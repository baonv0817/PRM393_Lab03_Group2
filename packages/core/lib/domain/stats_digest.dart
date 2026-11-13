import 'package:breakbite_core/domain/models/sales_report.dart';

/// The figures of the admin's statistics page as plain text, which is all the AI summary (docs/ai-feature.md,
/// section "Stats summary") receives. Only totals, kiosk names and dish names: no customer name, e-mail or order id.
String statsDigest({required SalesReport report, required int days, SalesReport? previous, String? kioskName}) {
  String vnd(int value) => '$value đồng';
  String change(num current, num before) {
    if (before == 0) return 'không so sánh được';
    final percent = ((current - before) / before * 100).round();
    return percent >= 0 ? 'tăng $percent%' : 'giảm ${-percent}%';
  }

  final out = StringBuffer()
    ..writeln('Phạm vi: ${kioskName ?? 'mọi kiosk'}, $days ngày gần nhất.')
    ..writeln(
      'Số đơn: ${report.orders} (đã giao ${report.delivered}, huỷ ${report.cancelled}, đang xử lý ${report.active}).',
    )
    ..writeln('Doanh thu: ${vnd(report.revenueVnd)}.')
    ..writeln('Giá trị mỗi đơn: ${vnd(report.averageOrderVnd)}.')
    ..writeln('Tỉ lệ huỷ: ${(report.cancelRate * 100).round()}%.');
  final prep = report.averagePrepSeconds;
  if (prep != null) out.writeln('Thời gian làm trung bình: ${(prep / 60).toStringAsFixed(1)} phút.');
  if (previous != null) {
    out
      ..writeln('So với $days ngày trước đó:')
      ..writeln('- số đơn ${change(report.orders, previous.orders)} (trước: ${previous.orders})')
      ..writeln('- doanh thu ${change(report.revenueVnd, previous.revenueVnd)} (trước: ${vnd(previous.revenueVnd)})')
      ..writeln('- tỉ lệ huỷ trước đó: ${(previous.cancelRate * 100).round()}%');
  }
  final busiest = <({int hour, int orders})>[
    for (var h = 0; h < report.byHour.length; h++)
      if (report.byHour[h] > 0) (hour: h, orders: report.byHour[h]),
  ]..sort((a, b) => b.orders.compareTo(a.orders));
  if (busiest.isNotEmpty) {
    out.writeln('Giờ đông nhất: ${busiest.take(3).map((b) => '${b.hour}h (${b.orders} đơn)').join(', ')}.');
  }
  if (report.byKiosk.length > 1) {
    out.writeln('Theo kiosk:');
    for (final k in report.byKiosk) {
      out.writeln('- ${k.kioskName}: ${k.orders} đơn, huỷ ${k.cancelled}, doanh thu ${vnd(k.revenueVnd)}');
    }
  }
  if (report.topDishes.isNotEmpty) {
    out.writeln('Món bán chạy:');
    for (final d in report.topDishes.take(5)) {
      out.writeln('- ${d.name}: ${d.quantity} phần');
    }
  }
  if (report.truncated) out.writeln('Lưu ý: số liệu chỉ tính trên các đơn mới nhất của khoảng này.');
  return out.toString().trimRight();
}
