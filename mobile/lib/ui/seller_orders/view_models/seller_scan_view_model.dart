import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// K05 and K05-ERR: finding the order a customer shows at the counter. The camera is not used (no scanner
/// package, D30); staff type what is under the QR code: the 6-digit pickup code, the order number "#A-204",
/// or the text of the QR code itself.
class SellerScanViewModel extends ChangeNotifier with SafeChangeNotifier {
  SellerScanViewModel({required this.orders, required this.crash, required this.kioskId});

  static const invalidMessage = 'Mã không hợp lệ hoặc đã hết hạn';
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
      final Result<Order> result;
      if (parsed.pickupCode != null) {
        final found = await orders.findReadyByPickupCode(id, parsed.pickupCode!);
        result = switch (found) {
          Ok(:final value) => _pick(value, parsed.orderId),
          Err(:final error) => Result.error(error),
        };
      } else {
        final queue = await orders.watchKioskQueue(id).first;
        final ready = queue.where((o) => o.status == OrderStatus.ready && _isNumber(o, parsed.orderNumber!)).toList();
        result = _pick(ready, null);
      }
      if (result case Err(:final error)) {
        _error = error is NotFoundException ? invalidMessage : error.message;
        if (error is! NotFoundException) crash.recordNonFatal(error, error.stackTrace, 'sellerScan.find');
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

  static bool _isNumber(Order order, String number) {
    final code = (order.orderCode.isEmpty ? order.id : order.orderCode).toUpperCase().replaceAll('#', '');
    return code == number;
  }

  static Result<Order> _pick(List<Order> orders, String? orderId) {
    final list = orderId == null ? orders : orders.where((o) => o.id == orderId).toList();
    if (list.isEmpty) return const Result.error(NotFoundException(message: invalidMessage));
    return Result.ok(list.first);
  }
}
