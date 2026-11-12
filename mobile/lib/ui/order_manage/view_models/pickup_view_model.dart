import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// S20: the pickup QR code of an order, large enough to scan, and whether it can still be used.
class PickupViewModel extends ChangeNotifier with SafeChangeNotifier {
  PickupViewModel({required this.orders, required this.crash, required this.orderId}) {
    load();
  }

  static const notFoundMessage = 'Không tìm thấy đơn này.';

  final OrderRepository orders;
  final CrashService crash;
  final String orderId;

  StreamSubscription<Order?>? _sub;
  ViewState<Order> _state = const ViewLoading();

  ViewState<Order> get state => _state;
  Order? get order => _state.dataOrNull;

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _sub = orders
        .watchOrder(orderId)
        .listen(
          (value) {
            _state = value == null ? const ViewEmpty(notFoundMessage) : ViewData(value);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'pickup.watchOrder');
            _state = ViewError(error is AppException ? error.message : 'Không tải được đơn hàng.');
            notifyListeners();
          },
        );
  }

  /// The code only means something while the order is open: once it is delivered or cancelled it is spent.
  bool get usable {
    final status = order?.status;
    return status != null && status != OrderStatus.delivered && status != OrderStatus.cancelled;
  }

  String get qrPayload => order?.qrPayload ?? '';

  /// The six digits in two groups of three, easier to read out to the kiosk.
  String get codeText {
    final code = order?.pickupCode ?? '';
    return code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
  }

  /// What to say about the code right now.
  String get statusLine {
    final o = order;
    if (o == null) return '';
    return switch (o.status) {
      OrderStatus.pending => 'Kiosk chưa nhận đơn. Mã dùng được khi món sẵn sàng.',
      OrderStatus.preparing => switch (o.readyBy) {
        final readyBy? => 'Kiosk đang làm món, dự kiến sẵn sàng lúc ${formatTime(readyBy)}.',
        null => 'Kiosk đang làm món.',
      },
      OrderStatus.ready => 'Món đã sẵn sàng. Đưa mã này cho kiosk.',
      OrderStatus.delivered => 'Bạn đã nhận món lúc ${formatTime(o.deliveredAt ?? o.updatedAt ?? o.createdAt)}.',
      OrderStatus.cancelled => 'Đơn đã huỷ nên mã không còn dùng được.',
    };
  }

  String get summaryLine => order == null ? '' : orderItemsSummary(order!);

  /// A cash order is paid at the counter, so the customer sees the amount next to the code.
  String? get paymentLine {
    final o = order;
    if (o == null || !usable) return null;
    final atCounter = o.paymentMethod == PaymentMethod.cash && o.paymentStatus == PaymentStatus.unpaid;
    return atCounter ? 'Trả tại quầy khi nhận: ${formatVnd(o.totalVnd)}' : null;
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
