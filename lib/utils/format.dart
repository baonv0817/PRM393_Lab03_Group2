import 'package:breakbite/domain/models/kiosk.dart';
import 'package:breakbite/domain/models/order.dart';
import 'package:breakbite/domain/models/voucher.dart';
import 'package:intl/intl.dart';

final _vnd = NumberFormat.decimalPattern('vi_VN');
final _time = DateFormat('HH:mm');
final _dayMonth = DateFormat('dd/MM');
final _date = DateFormat('dd/MM/yyyy');

String formatVnd(int amount) => '${_vnd.format(amount)}đ';

String formatTime(DateTime value) => _time.format(value.toLocal());

String formatDayMonth(DateTime value) => _dayMonth.format(value.toLocal());

String formatDate(DateTime value) => _date.format(value.toLocal());

String formatDateTime(DateTime value) => '${formatTime(value)} · ${formatDate(value)}';

String formatTimeLeft(DateTime target, {required DateTime now}) {
  final left = target.difference(now);
  if (left.isNegative) return 'đã quá giờ';
  if (left.inMinutes < 1) return 'còn dưới 1 phút';
  return 'còn ${left.inMinutes} phút';
}

String orderStatusLabel(OrderStatus status) => switch (status) {
  OrderStatus.pending => 'Đã nhận đơn',
  OrderStatus.preparing => 'Đang làm',
  OrderStatus.ready => 'Sẵn sàng',
  OrderStatus.delivered => 'Hoàn tất',
  OrderStatus.cancelled => 'Đã huỷ',
};

String voucherProblemMessage(Voucher voucher, VoucherProblem problem) => switch (problem) {
  VoucherProblem.inactive => 'Mã ${voucher.code} đã ngừng áp dụng.',
  VoucherProblem.notStarted => 'Mã ${voucher.code} chưa đến thời gian áp dụng.',
  VoucherProblem.expired => 'Mã ${voucher.code} đã hết hạn.',
  VoucherProblem.outsideActiveHours =>
    'Mã ${voucher.code} chỉ dùng từ ${voucher.activeFrom} đến ${voucher.activeTo} mỗi ngày.',
  VoucherProblem.belowMinimum => 'Đơn tối thiểu ${formatVnd(voucher.minOrderVnd)} để dùng mã ${voucher.code}.',
};

String voucherBenefit(Voucher voucher) {
  final amount = switch (voucher.discount) {
    FixedDiscount(:final amountVnd) => 'Giảm ${formatVnd(amountVnd)}',
    PercentDiscount(:final percent, :final maxVnd) => 'Giảm $percent%, tối đa ${formatVnd(maxVnd)}',
  };
  return voucher.minOrderVnd > 0 ? '$amount cho đơn từ ${formatVnd(voucher.minOrderVnd)}' : amount;
}

String orderItemsSummary(Order order) =>
    '${order.items.map((e) => '${e.name} ×${e.quantity}').join(', ')} · ${formatVnd(order.totalVnd)}';

String kioskStatusLabel(Kiosk kiosk, {required DateTime now}) {
  if (!kiosk.open) return kiosk.openTime == null ? 'Đang đóng cửa' : 'Đóng · mở lại ${kiosk.openTime}';
  final pausedUntil = kiosk.pausedUntil;
  if (pausedUntil != null && pausedUntil.isAfter(now)) return 'Tạm ngưng · nhận đơn lại lúc ${formatTime(pausedUntil)}';
  final low = kiosk.waitMinutes > 1 ? kiosk.waitMinutes - 1 : 1;
  return 'Mở · chờ $low–${kiosk.waitMinutes + 1} phút';
}

String paymentMethodLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.momo => 'Ví MoMo',
  PaymentMethod.vnpay => 'VNPAY-QR',
  PaymentMethod.card => 'Thẻ SV / Ví BreakBite',
  PaymentMethod.cash => 'Tiền mặt tại kiosk',
};

String paymentMethodHint(PaymentMethod method) => switch (method) {
  PaymentMethod.momo => 'Ví điện tử',
  PaymentMethod.vnpay => 'Quét mã bằng app ngân hàng',
  PaymentMethod.card => 'Trừ vào thẻ sinh viên',
  PaymentMethod.cash => 'Trả khi nhận món tại kiosk',
};
