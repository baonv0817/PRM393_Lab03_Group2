import 'dart:async';

import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/paged.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:breakbite_core/utils/text.dart';
import 'package:flutter/foundation.dart';

/// How far back the order list reaches.
enum OrderRange { today, week, month, all }

/// A06: the orders of every kiosk, to look at and never to change. An admin filters by kiosk, state and period,
/// finds an order by its code or the customer's name, and sees at a glance the orders stuck at "Chờ kiosk nhận"
/// (a counter that does not look at its phone).
class AdminOrdersViewModel extends ChangeNotifier with SafeChangeNotifier {
  AdminOrdersViewModel({required this.orders, required this.menu, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _kioskSub = menu.watchKiosks().listen((list) {
      _kiosks = list;
      notifyListeners();
    }, onError: (Object e, StackTrace s) {});
    load();
  }

  static const emptyMessage = 'Không có đơn nào khớp bộ lọc.';
  static const pageSize = 25;

  /// A pending order older than this is stuck: nobody at the kiosk has accepted it.
  static const stuckAfter = Duration(minutes: 15);

  final AdminOrderRepository orders;
  final MenuRepository menu;
  final DateTime Function() _clock;

  StreamSubscription<List<Kiosk>>? _kioskSub;
  List<Kiosk> _kiosks = const [];
  ViewState<List<Order>> _state = const ViewLoading();
  PageCursor? _next;
  bool _loadingMore = false;
  String? _moreError;
  String? _kioskId;
  OrderStatus? _status;
  OrderRange _range = OrderRange.week;
  bool _stuckOnly = false;
  String _search = '';
  int _generation = 0;

  DateTime get now => _clock();
  ViewState<List<Order>> get state => _state;
  List<Kiosk> get kiosks => _kiosks;
  String? get kioskId => _kioskId;
  OrderStatus? get status => _status;
  OrderRange get range => _range;
  bool get stuckOnly => _stuckOnly;
  String get search => _search;
  bool get hasMore => _next != null;
  bool get loadingMore => _loadingMore;

  /// The reason the last "Tải thêm" failed, or `null`.
  String? get moreError => _moreError;

  String kioskName(String id) => _kiosks.where((k) => k.id == id).firstOrNull?.name ?? id;

  bool isStuck(Order order) => order.status == OrderStatus.pending && now.difference(order.createdAt) >= stuckAfter;

  /// The first moment of the period on the Vietnam clock, or `null` for no limit.
  DateTime? get _from {
    final vietnam = now.toUtc().add(SlotPlan.vietnamOffset);
    final today = DateTime.utc(vietnam.year, vietnam.month, vietnam.day).subtract(SlotPlan.vietnamOffset);
    return switch (_range) {
      OrderRange.today => today,
      OrderRange.week => today.subtract(const Duration(days: 6)),
      OrderRange.month => today.subtract(const Duration(days: 29)),
      OrderRange.all => null,
    };
  }

  OrderQuery get _query =>
      OrderQuery(kioskId: _kioskId, status: _stuckOnly ? OrderStatus.pending : _status, from: _from);

  /// The loaded orders that match the search box (and, for "stuck", are old enough).
  List<Order> get visible {
    final all = _state.dataOrNull ?? const <Order>[];
    final needle = searchKey(_search.trim());
    return [
      for (final o in all)
        if ((!_stuckOnly || isStuck(o)) &&
            (needle.isEmpty || searchKey('${o.orderCode} ${o.customerName} ${o.pickupCode} ${o.id}').contains(needle)))
          o,
    ];
  }

  int get stuckCount => (_state.dataOrNull ?? const <Order>[]).where(isStuck).length;

  Future<void> load() async {
    final generation = ++_generation;
    _state = const ViewLoading();
    _next = null;
    _moreError = null;
    notifyListeners();
    final result = await orders.fetchOrders(_query, limit: pageSize);
    if (generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        _state = value.items.isEmpty ? const ViewEmpty(emptyMessage) : ViewData(value.items);
        _next = value.next;
      case Err(:final error):
        _state = ViewError(error.message);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    final cursor = _next;
    final loaded = _state.dataOrNull;
    if (cursor == null || loaded == null || _loadingMore) return;
    final generation = _generation;
    _loadingMore = true;
    _moreError = null;
    notifyListeners();
    final result = await orders.fetchOrders(_query, limit: pageSize, after: cursor);
    if (generation != _generation) return;
    _loadingMore = false;
    switch (result) {
      case Ok(:final value):
        _state = ViewData([...loaded, ...value.items]);
        _next = value.next;
      case Err(:final error):
        _moreError = error.message;
    }
    notifyListeners();
  }

  void setKiosk(String? id) {
    if (id == _kioskId) return;
    _kioskId = id;
    unawaited(load());
  }

  void setStatus(OrderStatus? value) {
    if (value == _status && !_stuckOnly) return;
    _status = value;
    _stuckOnly = false;
    unawaited(load());
  }

  void setRange(OrderRange value) {
    if (value == _range) return;
    _range = value;
    unawaited(load());
  }

  /// Shows only the stuck orders (pending, older than [stuckAfter]).
  void setStuckOnly(bool value) {
    if (value == _stuckOnly) return;
    _stuckOnly = value;
    if (value) _status = null;
    unawaited(load());
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_kioskSub?.cancel());
    super.dispose();
  }
}
