import 'dart:async';

import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// S10: what happened to a cancelled order, whether the customer is refunded, and a one-tap reorder.
class OrderCancelledViewModel extends ChangeNotifier with SafeChangeNotifier {
  OrderCancelledViewModel({
    required this.orders,
    required this.cart,
    required this.session,
    required this.analytics,
    required this.crash,
    required this.uid,
    required this.orderId,
  }) {
    reorder = Command0(_reorder);
    load();
  }

  static const notFoundMessage = 'Không tìm thấy đơn này.';
  static const notCancelledMessage = 'Đơn này chưa bị huỷ.';

  final OrderRepository orders;
  final CartRepository cart;
  final SessionRepository session;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;
  final String orderId;

  late final Command0<int> reorder;

  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'order_cancelled',
    onChanged: notifyListeners,
  );
  StreamSubscription<Order?>? _sub;
  ViewState<Order> _state = const ViewLoading();
  bool _notCancelled = false;

  ViewState<Order> get state => _state;
  Order? get order => _state.dataOrNull;

  /// The order exists but is still open, so S10 does not apply and S07 is the right screen.
  bool get notCancelled => _notCancelled;

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    _notCancelled = false;
    notifyListeners();
    _sub = orders
        .watchOrder(orderId)
        .listen(
          (value) {
            _notCancelled = value != null && value.status != OrderStatus.cancelled;
            _state = value == null
                ? const ViewEmpty(notFoundMessage)
                : (_notCancelled ? const ViewEmpty(notCancelledMessage) : ViewData(value));
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'orderCancelled.watchOrder');
            _state = ViewError(error is AppException ? error.message : 'Không tải được đơn hàng.');
            notifyListeners();
          },
        );
  }

  /// Who ended the order, in the customer's words.
  String get whoLine => switch (order?.cancelledBy) {
    CancelledBy.customer => 'Bạn đã huỷ đơn này.',
    CancelledBy.staff => 'Kiosk đã từ chối đơn này.',
    null => 'Đơn này đã bị huỷ.',
  };

  /// The reason staff gave. A customer's own cancellation carries a fixed note, so it is not shown back to them.
  String? get reasonLine {
    final o = order;
    if (o == null || o.cancelledBy == CancelledBy.customer) return null;
    final reason = o.cancelReason?.trim() ?? '';
    return reason.isEmpty ? null : 'Lý do: $reason';
  }

  String get cancelledAtLine {
    final o = order;
    if (o == null) return '';
    return 'Huỷ lúc ${formatDateTime(o.cancelledAt ?? o.updatedAt ?? o.createdAt)}';
  }

  bool get refunded => order?.paymentStatus == PaymentStatus.paid;

  String get refundLine {
    final o = order;
    if (o == null) return '';
    if (!refunded) return 'Bạn chưa trả tiền cho đơn này nên không có khoản nào cần hoàn.';
    return 'Hoàn ${formatVnd(o.totalVnd)} về ${paymentMethodLabel(o.paymentMethod)} trong khoảng 30 giây.';
  }

  String get itemsLine => order?.items.map((i) => '${i.displayName} ×${i.quantity}').join(', ') ?? '';

  String get totalLine {
    final o = order;
    if (o == null) return '';
    final discount = o.discountVnd > 0 ? ' · đã giảm ${formatVnd(o.discountVnd)}' : '';
    return 'Tổng ${formatVnd(o.totalVnd)}$discount';
  }

  Future<Result<int>> _reorder() async {
    final o = order;
    if (o == null) return const Result.error(NotFoundException(message: notFoundMessage));
    final result = await _cart.reorder(o);
    if (result is Ok<int>) await session.selectKiosk(o.kioskId);
    return result;
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    reorder.dispose();
    super.dispose();
  }
}
