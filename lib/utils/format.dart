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
