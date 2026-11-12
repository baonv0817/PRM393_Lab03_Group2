import 'dart:async';

import 'package:breakbite/ui/seller_orders/view_models/seller_order_actions.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// The three lists of K02, one for each step of an order at the counter.
enum SellerOrderTab {
  pending('Mới', OrderStatus.pending),
  preparing('Đang làm', OrderStatus.preparing),
  ready('Sẵn sàng', OrderStatus.ready);

  const SellerOrderTab(this.label, this.status);

  final String label;
  final OrderStatus status;
}

/// K02 (and K02-EMPTY): the live queue of the staff member's kiosk. New orders appear by themselves; the
/// "Nhận đơn" button on a card starts the order without opening it.
class SellerOrdersViewModel extends ChangeNotifier with SafeChangeNotifier {
  SellerOrdersViewModel({
    required this.orders,
    required this.menu,
    required this.incidents,
    required this.crash,
    required this.analytics,
    required this.alerts,
    required this.kioskId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    load();
  }

  static const noKioskMessage =
      'Tài khoản này chưa được gán kiosk nên chưa có đơn nào. Nhờ quản trị viên gán kiosk cho bạn.';
  static const emptyMessage = 'Đơn mới sẽ hiện ở đây cùng âm báo.';

  final OrderRepository orders;
  final MenuRepository menu;
  final IncidentRepository incidents;
  final CrashService crash;
  final AnalyticsService analytics;

  /// Rings the phone when an order arrives while the list is open.
  final OrderAlertService alerts;
  final String? kioskId;
  final DateTime Function() _clock;

  StreamSubscription<List<Order>>? _ordersSub;

  /// The orders waiting to be accepted at the last snapshot; `null` until the first one arrives, so the orders
  /// that were already there when the list opened do not ring.
  Set<String>? _knownPending;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  StreamSubscription<List<Incident>>? _incidentSub;
  ViewState<List<Order>> _state = const ViewLoading();
  Kiosk? _kiosk;
  SellerOrderTab _tab = SellerOrderTab.pending;
  int _openIncidents = 0;
  String? _busyOrderId;

  ViewState<List<Order>> get state => _state;
  SellerOrderTab get tab => _tab;
  Kiosk? get kiosk => _kiosk;
  DateTime get now => _clock();

  /// The id of the order whose "Nhận đơn" is being written, so its button shows progress.
  String? get busyOrderId => _busyOrderId;

  /// Reports of customers that nobody has answered yet (the bell of K02).
  int get openIncidents => _openIncidents;

  bool get hasKiosk => kioskId != null && kioskId!.isNotEmpty;

  /// "Mở · chờ 5–7 phút" under the title.
  String get statusLine => _kiosk == null ? '' : kioskStatusLabel(_kiosk!, now: now);

  bool get acceptsOrders => _kiosk?.acceptsOrders(now) ?? false;

  List<Order> get all => _state.dataOrNull ?? const [];

  int countOf(SellerOrderTab t) => all.where((o) => o.status == t.status).length;

  /// The orders of the chosen tab, the one to hand over first at the top: by pickup time, then by arrival.
  List<Order> get visible {
    final list = all.where((o) => o.status == _tab.status).toList();
    list.sort((a, b) {
      final byPickup = (a.pickupAt ?? a.createdAt).compareTo(b.pickupAt ?? b.createdAt);
      return byPickup != 0 ? byPickup : a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  void select(SellerOrderTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }

  /// Rings for the orders that are waiting and were not at the last snapshot. Accepting or turning an order down
  /// takes it out of the waiting ones and never rings.
  void _alertForNew(List<Order> list) {
    final pending = {
      for (final o in list)
        if (o.status == OrderStatus.pending) o.id: o,
    };
    final known = _knownPending;
    _knownPending = pending.keys.toSet();
    if (known == null) return;
    final fresh = pending.keys.where((id) => !known.contains(id)).toList();
    if (fresh.isEmpty) return;
    final code = fresh.length == 1 ? pending[fresh.single]!.orderCode : null;
    unawaited(alerts.newOrders(count: fresh.length, orderCode: code == null || code.isEmpty ? null : code));
  }

  void load() {
    unawaited(_ordersSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_incidentSub?.cancel());
    final id = kioskId;
    if (id == null || id.isEmpty) {
      _state = const ViewEmpty(noKioskMessage);
      notifyListeners();
      return;
    }
    _state = const ViewLoading();
    _knownPending = null;
    notifyListeners();
    _ordersSub = orders
        .watchKioskQueue(id)
        .listen(
          (list) {
            _state = ViewData(list);
            _alertForNew(list);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'sellerOrders.watchKioskQueue');
            _state = ViewError(error is AppException ? error.message : 'Không tải được danh sách đơn.');
            notifyListeners();
          },
        );
    // Both are extras of the header: a failure here must not hide the orders.
    _kioskSub = menu.watchKiosks().listen((kiosks) {
      _kiosk = kiosks.where((k) => k.id == id).firstOrNull;
      notifyListeners();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'sellerOrders.watchKiosks'));
    _incidentSub = incidents.watchKioskIncidents(id).listen((list) {
      _openIncidents = list.where((i) => i.status == IncidentStatus.open).length;
      notifyListeners();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'sellerOrders.watchIncidents'));
  }

  /// "Nhận đơn" on a card: the order starts and moves to "Đang làm".
  Future<Result<void>> accept(Order order) async {
    if (_busyOrderId != null) return const Result.ok(null);
    _busyOrderId = order.id;
    notifyListeners();
    try {
      final result = await orders.accept(
        order,
        readyIn: readyInFor(order, now: now, kioskWaitMinutes: _kiosk?.waitMinutes),
      );
      switch (result) {
        case Ok():
          logOrderAccepted(analytics, order, now);
        case Err(:final error):
          crash.recordNonFatal(error, error.stackTrace, 'sellerOrders.accept');
      }
      return result;
    } finally {
      _busyOrderId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_ordersSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_incidentSub?.cancel());
    super.dispose();
  }
}
