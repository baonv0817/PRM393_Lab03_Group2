import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// S14: the sheet that opens from Home with the customer's recent orders. One is chosen (the newest at first)
/// and all of its dishes go into the cart at once; the cart then opens (S05) so the customer can pay.
class QuickReorderViewModel extends ChangeNotifier with SafeChangeNotifier {
  QuickReorderViewModel({
    required this.orders,
    required this.cart,
    required this.analytics,
    required this.crash,
    required this.uid,
  }) {
    reorder = Command0(_reorder);
    _cart.start();
    load();
  }

  static const maxOrders = 5;
  static const emptyMessage = 'Bạn chưa có đơn nào để đặt lại.';

  final OrderRepository orders;
  final CartRepository cart;
  final AnalyticsService analytics;
  final CrashService crash;
  final String uid;

  /// Puts the chosen order's dishes in the cart; its result is how many dishes were added.
  late final Command0<int> reorder;

  late final _cart = CartControls(
    cart: cart,
    analytics: analytics,
    crash: crash,
    uid: uid,
    source: 'quick_reorder',
    onChanged: notifyListeners,
  );

  StreamSubscription<List<Order>>? _sub;
  ViewState<List<Order>> _state = const ViewLoading();
  String? _chosenId;

  ViewState<List<Order>> get state => _state;

  /// The order that is selected: the one the customer tapped, else the newest.
  Order? get chosen {
    final list = _state.dataOrNull;
    if (list == null || list.isEmpty) return null;
    return list.where((o) => o.id == _chosenId).firstOrNull ?? list.first;
  }

  /// What the main button of the sheet says it adds, for example "Thêm vào giỏ · 54.000đ".
  int? get chosenTotalVnd => chosen?.totalVnd;

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _sub = orders
        .watchMyOrders(uid, limit: 20)
        .listen(
          (list) {
            // A cancelled order was never eaten; the order screens already offer to order it again.
            final recent = list.where((o) => o.status != OrderStatus.cancelled).take(maxOrders).toList();
            _state = ViewStateX.fromList(recent, emptyMessage: emptyMessage);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'quickReorder.watchOrders');
            _state = ViewError(error is AppException ? error.message : 'Không tải được đơn gần đây.');
            notifyListeners();
          },
        );
  }

  void choose(Order order) {
    if (order.id == _chosenId) return;
    _chosenId = order.id;
    notifyListeners();
  }

  Future<Result<int>> _reorder() async {
    final order = chosen;
    if (order == null) return const Result.error(NotFoundException(message: emptyMessage));
    return _cart.reorder(order);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _cart.stop();
    reorder.dispose();
    super.dispose();
  }
}
