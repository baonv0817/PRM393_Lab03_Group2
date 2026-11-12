import 'dart:async';

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

class OrderTrackingViewModel extends ChangeNotifier with SafeChangeNotifier {
  OrderTrackingViewModel({
    required this.orders,
    required this.menu,
    required this.crash,
    required this.orderId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    cancel = Command0(_cancel);
    load();
  }

  static const steps = ['Đã nhận', 'Đang làm', 'Sẵn sàng', 'Hoàn tất'];

  final OrderRepository orders;
  final MenuRepository menu;
  final CrashService crash;
  final String orderId;
  final DateTime Function() _clock;

  late final Command0<void> cancel;

  StreamSubscription<Order?>? _orderSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  ViewState<Order> _state = const ViewLoading();
  List<Kiosk> _kiosks = const [];

  ViewState<Order> get state => _state;
  Order? get order => _state.dataOrNull;
  DateTime get now => _clock();

  Kiosk? get kiosk {
    final o = order;
    return o == null ? null : _kiosks.where((k) => k.id == o.kioskId).firstOrNull;
  }

  void load() {
    unawaited(_orderSub?.cancel());
    unawaited(_kioskSub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _orderSub = orders
        .watchOrder(orderId)
        .listen(
          (value) {
            _state = value == null ? const ViewEmpty('Không tìm thấy đơn này.') : ViewData(value);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'orderTracking.watchOrder');
            _state = ViewError(error is AppException ? error.message : 'Không tải được đơn hàng.');
            notifyListeners();
          },
        );
    _kioskSub = menu.watchKiosks().listen((value) {
      _kiosks = value;
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => crash.recordNonFatal(error, stack, 'orderTracking.watchKiosks'));
  }

  bool get canChange => order?.status == OrderStatus.pending;

  bool get paysAtCounter {
    final o = order;
    return o != null && o.paymentMethod == PaymentMethod.cash && o.paymentStatus == PaymentStatus.unpaid;
  }

  int get stepIndex => switch (order?.status) {
    OrderStatus.preparing => 1,
    OrderStatus.ready => 2,
    OrderStatus.delivered => 3,
    _ => 0,
  };

  String get badge {
    final o = order;
    if (o == null) return '';
    if (o.status != OrderStatus.cancelled && paysAtCounter) return 'Trả tại quầy';
    return orderStatusLabel(o.status);
  }

  String get timing {
    final o = order;
    if (o == null) return '';
    return switch (o.status) {
      OrderStatus.pending => 'Chờ kiosk nhận đơn',
      OrderStatus.preparing => switch (o.readyBy) {
        final readyBy? => 'Dự kiến sẵn sàng ${formatTime(readyBy)} (${formatTimeLeft(readyBy, now: now)})',
        null => 'Kiosk đang làm món',
      },
      OrderStatus.ready => 'Món đã sẵn sàng, mời bạn tới quầy',
      OrderStatus.delivered => 'Đã nhận món lúc ${formatTime(o.deliveredAt ?? o.updatedAt ?? o.createdAt)}',
      OrderStatus.cancelled => 'Đơn đã huỷ${o.cancelReason == null ? '' : ': ${o.cancelReason}'}',
    };
  }

  String get paymentLine {
    final o = order;
    if (o == null) return '';
    if (paysAtCounter) return 'Trả tại quầy khi nhận: ${formatVnd(o.totalVnd)}';
    return 'Tổng ${formatVnd(o.totalVnd)} · Đã thanh toán ${paymentMethodLabel(o.paymentMethod)}';
  }

  String get cancelMessage {
    final o = order;
    if (o == null) return '';
    final refund = o.paymentStatus == PaymentStatus.paid
        ? 'Hoàn ${formatVnd(o.totalVnd)} về ${paymentMethodLabel(o.paymentMethod)} trong khoảng 30 giây. '
        : '';
    return '${refund}Chỉ huỷ được khi bếp chưa làm.';
  }

  Future<Result<void>> _cancel() async {
    final o = order;
    if (o == null) return const Result.error(NotFoundException(message: 'Không tìm thấy đơn này.'));
    final result = await orders.cancelMyOrder(o, reason: 'Khách huỷ trên ứng dụng');
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'orderTracking.cancel');
    return result;
  }

  @override
  void dispose() {
    unawaited(_orderSub?.cancel());
    unawaited(_kioskSub?.cancel());
    cancel.dispose();
    super.dispose();
  }
}
