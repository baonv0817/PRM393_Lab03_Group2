import 'dart:async';

import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// W03 Review queue: the orders customers placed on the mobile app (status `pending`) wait here until staff
/// approve them (`preparing`, with a time to be ready) or reject them with a reason (`cancelled`). Both are the
/// write the mobile order tracking screen (S07) listens to, so the customer sees the result in real time
/// (docs/cross-role-flow.md).
class ReviewQueueViewModel extends ChangeNotifier with SafeChangeNotifier {
  ReviewQueueViewModel({required this._orders, required this.kioskId}) {
    approve = Command1(_approve);
    reject = Command1(_reject);
    _listen();
  }

  /// Times staff can promise, in minutes; the first is the default.
  static const readyInChoices = [10, 5, 15, 20];

  /// Reasons offered when rejecting; staff may also type their own.
  static const rejectReasons = ['Hết nguyên liệu', 'Quầy sắp đóng cửa', 'Quá tải, không kịp làm', 'Đơn trùng'];

  final OrderRepository _orders;
  final String kioskId;
  StreamSubscription<List<Order>>? _sub;

  late final Command1<void, Duration> approve;
  late final Command1<void, String> reject;

  ViewState<List<Order>> _state = const ViewLoading();
  int _inProgress = 0;
  String? _selectedId;

  /// Pending orders, oldest first: the customer who waited longest is served first.
  ViewState<List<Order>> get state => _state;

  /// Orders already approved and not handed over yet (preparing or ready), for the header.
  int get inProgressCount => _inProgress;

  Order? get selected {
    final orders = _state.dataOrNull ?? const <Order>[];
    return orders.where((o) => o.id == _selectedId).firstOrNull ?? orders.firstOrNull;
  }

  void select(Order order) {
    if (order.id == _selectedId) return;
    _selectedId = order.id;
    approve.clearResult();
    reject.clearResult();
    notifyListeners();
  }

  void retry() {
    _sub?.cancel();
    _state = const ViewLoading();
    notifyListeners();
    _listen();
  }

  void _listen() {
    _sub = _orders
        .watchKioskQueue(kioskId)
        .listen(
          (orders) {
            final pending = orders.where((o) => o.status == OrderStatus.pending).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            _inProgress = orders.length - pending.length;
            _state = ViewStateX.fromList(pending, emptyMessage: 'Không có đơn nào chờ duyệt.');
            notifyListeners();
          },
          onError: (Object error) {
            _state = ViewError(error is AppException ? error.message : 'Không tải được hàng chờ. Thử lại.');
            notifyListeners();
          },
        );
  }

  Future<Result<void>> _approve(Duration readyIn) async {
    final order = selected;
    if (order == null) return const Result.error(ValidationException('Chọn một đơn để duyệt.'));
    return _orders.accept(order, readyIn: readyIn);
  }

  Future<Result<void>> _reject(String reason) async {
    final order = selected;
    if (order == null) return const Result.error(ValidationException('Chọn một đơn để từ chối.'));
    return _orders.reject(order, reason: reason);
  }

  @override
  void dispose() {
    _sub?.cancel();
    approve.dispose();
    reject.dispose();
    super.dispose();
  }
}
