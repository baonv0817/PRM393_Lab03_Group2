import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// K05 and K05-ERR: finding the order a customer shows at the counter. The input is what the camera reads from the QR
/// code or what staff type: the 6-digit pickup code, the order number "#A-204", or the text of the QR code itself.
///
/// Only a ready order can be handed over. A code of an order in another state is not "invalid": the message names the
/// state ("đang làm, bấm Sẵn sàng trước"), so staff know what to do.
class SellerScanViewModel extends ChangeNotifier with SafeChangeNotifier {
  SellerScanViewModel({required this.orders, required this.crash, required this.kioskId});

  /// No order at this kiosk has this code. A pickup code does not expire, so the message does not say it can.
  static const invalidMessage = 'Không tìm thấy đơn nào với mã này ở kiosk của bạn. Kiểm tra lại mã 6 số hoặc số đơn.';
  static const emptyMessage = 'Nhập mã nhận món hoặc số đơn.';
  static const noKioskMessage = 'Tài khoản này chưa được gán kiosk.';

  final OrderRepository orders;
  final CrashService crash;
  final String? kioskId;

  bool _searching = false;
  String? _error;

  bool get searching => _searching;

  /// Set after a failed search (the viewfinder gets its error border); cleared by the next search or edit.
  String? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// What a QR code or a typed text means: the order id and pickup code of a QR, a pickup code, or an order
  /// number.
  static ({String? orderId, String? pickupCode, String? orderNumber}) parse(String input) {
    final text = input.trim();
    final qr = RegExp(r'^bb:([^:]+):(\d{6})$').firstMatch(text);
    if (qr != null) return (orderId: qr.group(1), pickupCode: qr.group(2), orderNumber: null);
    final digits = text.replaceAll(RegExp(r'[\s-]'), '');
    if (RegExp(r'^\d{6}$').hasMatch(digits)) return (orderId: null, pickupCode: digits, orderNumber: null);
    final number = text.toUpperCase().replaceAll('#', '').replaceAll(' ', '');
    if (number.isNotEmpty) return (orderId: null, pickupCode: null, orderNumber: number);
    return (orderId: null, pickupCode: null, orderNumber: null);
  }

  /// The order that is ready to hand over for [input], or an error. Only an order that is "Sẵn sàng" counts:
  /// a code of an order not ready, delivered or cancelled is as wrong as a mistyped one.
  Future<Result<Order>> find(String input) async {
    final id = kioskId;
    if (id == null || id.isEmpty) return const Result.error(PermissionDeniedException(message: noKioskMessage));
    final parsed = parse(input);
    if (parsed.orderId == null && parsed.pickupCode == null && parsed.orderNumber == null) {
      _error = emptyMessage;
      notifyListeners();
      return const Result.error(ValidationException(emptyMessage));
    }
    if (_searching) return const Result.error(ValidationException('Đang tìm đơn…'));
    _searching = true;
    _error = null;
    notifyListeners();
    try {
      final found = await orders.findAtKiosk(id, pickupCode: parsed.pickupCode, orderCode: parsed.orderNumber);
      final Result<Order> result = switch (found) {
        Ok(:final value) => _pick(value, parsed.orderId),
        Err(:final error) => Result.error(error),
      };
      if (result case Err(:final error)) {
        _error = error.message;
        // A code with no order, or an order that is not ready, is what the counter expects now and then; anything
        // else (network, rules) is worth a look.
        if (error is! NotFoundException && error is! ValidationException) {
          crash.recordNonFatal(error, error.stackTrace, 'sellerScan.find');
        }
      }
      return result;
    } catch (error, stack) {
      crash.recordNonFatal(error, stack, 'sellerScan.find');
      _error = 'Không tìm được đơn. Kiểm tra mạng rồi thử lại.';
      return Result.error(error is AppException ? error : NetworkException(cause: error, stackTrace: stack));
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  /// The ready order of [orders] (newest first), or the reason the code cannot be handed over: no order, or an order
  /// in another state, named so that staff know what to do ("đang làm: bấm Sẵn sàng trước").
  static Result<Order> _pick(List<Order> orders, String? orderId) {
    final list = orderId == null ? orders : orders.where((o) => o.id == orderId).toList();
    if (list.isEmpty) return const Result.error(NotFoundException(message: invalidMessage));
    final ready = list.where((o) => o.status == OrderStatus.ready);
    if (ready.isNotEmpty) return Result.ok(ready.first);
    return Result.error(ValidationException(notReadyMessage(list.first)));
  }

  /// Why [order], found by its code, cannot be handed over.
  static String notReadyMessage(Order order) {
    final number = '#${order.orderCode.isEmpty ? order.id : order.orderCode}';
    return switch (order.status) {
      OrderStatus.pending when order.awaitingPayment => 'Đơn $number khách chưa thanh toán xong nên chưa giao được.',
      OrderStatus.pending => 'Đơn $number chưa được nhận. Nhận đơn và làm xong rồi mới giao.',
      OrderStatus.preparing => 'Đơn $number đang làm, chưa sẵn sàng. Bấm "Sẵn sàng" khi xong rồi quét lại.',
      OrderStatus.delivered => 'Đơn $number đã giao xong.',
      OrderStatus.cancelled => 'Đơn $number đã huỷ, không giao được.',
      OrderStatus.ready => 'Đơn $number đã sẵn sàng.',
    };
  }
}
