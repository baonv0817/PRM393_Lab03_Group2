import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

class ProfileViewModel extends ChangeNotifier with SafeChangeNotifier {
  ProfileViewModel({required this.orders, required this.crash, required this.uid}) {
    unawaited(load());
  }

  final OrderRepository orders;
  final CrashService crash;
  final String uid;

  ViewState<int> _orderCount = const ViewLoading();

  ViewState<int> get orderCount => _orderCount;

  String get orderCountLabel => switch (_orderCount) {
    ViewData(:final data) => '$data đơn đã đặt',
    ViewError() => 'Không tải được số đơn',
    _ => 'Đang tải số đơn…',
  };

  Future<void> load() async {
    _orderCount = const ViewLoading();
    notifyListeners();
    final result = await orders.countMyOrders(uid);
    switch (result) {
      case Ok(:final value):
        _orderCount = ViewData(value);
      case Err(:final error):
        _orderCount = ViewError(error.message);
        unawaited(crash.recordError(error.cause ?? error, error.stackTrace, reason: 'profile.countMyOrders'));
    }
    notifyListeners();
  }
}
