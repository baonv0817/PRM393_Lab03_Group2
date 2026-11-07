import 'package:breakbite/data/repositories/order_repository.dart';
import 'package:breakbite/domain/models/models.dart';

/// How long the kitchen needs for [order]: until the pickup time the customer chose when that is far enough
/// away, otherwise the kiosk's usual wait (at least 5 minutes). Never below [OrderRepository.minReadyIn].
Duration readyInFor(Order order, {required DateTime now, int? kioskWaitMinutes}) {
  const fallback = Duration(minutes: 5);
  final pickupAt = order.pickupAt;
  if (pickupAt != null) {
    final untilPickup = pickupAt.difference(now);
    if (untilPickup >= OrderRepository.minReadyIn) return untilPickup;
  }
  final usual = Duration(minutes: kioskWaitMinutes ?? 0);
  return usual > fallback ? usual : fallback;
}

/// The reasons K12 offers when staff turn an order down.
enum RejectReason {
  soldOut('Hết món'),
  busy('Quá tải, không kịp giờ'),
  other('Lý do khác');

  const RejectReason(this.label);

  final String label;
}

/// The text saved with a rejected order: the chosen reason, plus the typed one for "other".
String rejectReasonText(RejectReason reason, String typed) {
  final extra = typed.trim();
  return switch (reason) {
    RejectReason.other => extra,
    _ => extra.isEmpty ? reason.label : '${reason.label}: $extra',
  };
}

/// A message for [rejectReasonText] when it cannot be sent, or `null`.
String? rejectReasonProblem(RejectReason reason, String typed) =>
    reason == RejectReason.other && typed.trim().isEmpty ? 'Nhập lý do để khách biết.' : null;

/// The big text of K04: "Còn 02:35" while there is time, "Trễ 00:40" once it has run out, "Trễ hơn 2 giờ" when
/// the order is hours late (minutes alone would read like a mistake), "Đang làm" when no time was promised.
String countdownLabel(Duration? left) {
  if (left == null) return 'Đang làm';
  String two(int v) => v.toString().padLeft(2, '0');
  final total = left.inSeconds.abs();
  if (left.isNegative && total >= 3600) return 'Trễ hơn ${total ~/ 3600} giờ';
  final clock = '${two(total ~/ 60)}:${two(total % 60)}';
  return left.isNegative ? 'Trễ $clock' : 'Còn $clock';
}
