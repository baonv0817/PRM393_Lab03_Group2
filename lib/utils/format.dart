import 'package:breakbite/domain/models/incident.dart';
import 'package:breakbite/domain/models/kiosk.dart';
import 'package:breakbite/domain/models/menu_item.dart';
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

String incidentTypeLabel(IncidentType type) => switch (type) {
  IncidentType.missingItem => 'Thiếu món',
  IncidentType.wrongItem => 'Sai món',
  IncidentType.quality => 'Món chưa đạt chất lượng',
  IncidentType.late => 'Làm món quá lâu',
  IncidentType.other => 'Vấn đề khác',
};

/// Where a report stands, in the customer's words (S24).
String incidentStatusLabel(IncidentStatus status) => switch (status) {
  IncidentStatus.open => 'Đã gửi, chờ kiosk xem',
  IncidentStatus.inProgress => 'Kiosk đang xử lý',
  IncidentStatus.resolved => 'Đã xử lý',
};

String itemCategoryLabel(ItemCategory category) => switch (category) {
  ItemCategory.food => 'Món ăn',
  ItemCategory.drink => 'Đồ uống',
  ItemCategory.other => 'Khác',
};

/// Why an item is sold out, as staff pick it in K09.
String soldOutReasonLabel(SoldOutReason reason) => switch (reason) {
  SoldOutReason.outOfIngredients => 'Hết nguyên liệu',
  SoldOutReason.machineBroken => 'Máy móc hỏng',
  SoldOutReason.other => 'Lý do khác',
};

/// The quick tags of a review (S23); an unknown tag is shown as it was stored.
String reviewTagLabel(String tag) => switch (tag) {
  'tasty' => 'Ngon',
  'fast' => 'Ra món nhanh',
  'hot' => 'Còn nóng',
  'wellPacked' => 'Đóng gói kỹ',
  _ => tag,
};

/// What a star rating means, said under the stars (S23).
String ratingLabel(int stars) => switch (stars) {
  1 => 'Rất tệ',
  2 => 'Chưa tốt',
  3 => 'Bình thường',
  4 => 'Tốt',
  5 => 'Tuyệt vời',
  _ => 'Chạm vào sao để chấm điểm',
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

/// Sum of the item lines, before any voucher.
int orderItemsTotalVnd(Order order) => order.items.fold(0, (sum, item) => sum + item.lineTotalVnd);

/// Where the money stands, in the customer's words (S12 and the PDF receipt).
String orderPaymentLabel(Order order) {
  final paid = order.paymentStatus == PaymentStatus.paid;
  final cancelled = order.status == OrderStatus.cancelled;
  if (paid) return cancelled ? 'Được hoàn tiền' : 'Đã thanh toán';
  return cancelled ? 'Chưa thanh toán' : 'Trả tại quầy khi nhận';
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

/// "3 phút 20 giây", "45 giây" or "—" when nothing was measured.
String prepTimeLabel(double? seconds) {
  if (seconds == null) return '—';
  final total = seconds.round();
  final minutes = total ~/ 60;
  final rest = total % 60;
  if (minutes == 0) return '$rest giây';
  return rest == 0 ? '$minutes phút' : '$minutes phút $rest giây';
}
