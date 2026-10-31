import 'package:breakbite/domain/models/order.dart';
import 'package:intl/intl.dart';

final _vnd = NumberFormat.decimalPattern('vi_VN');
final _time = DateFormat('HH:mm');
final _dayMonth = DateFormat('dd/MM');
final _date = DateFormat('dd/MM/yyyy');

/// `39000` becomes `39.000đ`.
String formatVnd(int amount) => '${_vnd.format(amount)}đ';

/// `10:20` (24-hour clock, local time).
String formatTime(DateTime value) => _time.format(value.toLocal());

/// `14/10`, used in order lists.
String formatDayMonth(DateTime value) => _dayMonth.format(value.toLocal());

/// `14/10/2026`.
String formatDate(DateTime value) => _date.format(value.toLocal());

/// `10:22 · 14/10/2026`, used on order details.
String formatDateTime(DateTime value) => '${formatTime(value)} · ${formatDate(value)}';

/// Time left until [target], as shown on order tracking (S07) and preparing (K04):
/// `còn 3 phút`, `còn dưới 1 phút`, or `đã quá giờ` once [target] has passed.
String formatTimeLeft(DateTime target, {required DateTime now}) {
  final left = target.difference(now);
  if (left.isNegative) return 'đã quá giờ';
  if (left.inMinutes < 1) return 'còn dưới 1 phút';
  return 'còn ${left.inMinutes} phút';
}

/// Status name shown to the user.
String orderStatusLabel(OrderStatus status) => switch (status) {
  OrderStatus.pending => 'Đã nhận đơn',
  OrderStatus.preparing => 'Đang làm',
  OrderStatus.ready => 'Sẵn sàng',
  OrderStatus.delivered => 'Hoàn tất',
  OrderStatus.cancelled => 'Đã huỷ',
};
