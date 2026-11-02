import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

enum SellerMenuFilter { all, available, soldOut }

/// The items of one category, as K08 lists them.
class MenuGroup {
  const MenuGroup({required this.category, required this.label, required this.items});

  final ItemCategory category;
  final String label;
  final List<MenuItem> items;
}

/// K08 and K09: the menu of the staff member's kiosk, with the switch that marks an item sold out (with a
/// reason and when it is expected back) or available again.
///
/// Lays out as a plain list that works on a phone and, kept in a centered column, on a wide screen; the
/// web admin of the final assignment reuses it for the menu management screen.
class SellerMenuViewModel extends ChangeNotifier with SafeChangeNotifier {
  SellerMenuViewModel({required this.menu, required this.crash, required this.kioskId, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    load();
  }

  static const noKioskMessage =
      'Tài khoản này chưa được gán kiosk nên chưa có món để quản lý. Nhờ quản trị viên gán kiosk cho bạn.';
  static const emptyMessage = 'Kiosk chưa có món nào.';

  /// When a sold-out item is expected back, counted from now; `null` means "not known".
  static const backChoices = <Duration?>[null, Duration(minutes: 30), Duration(hours: 1), Duration(hours: 2)];

  final MenuRepository menu;
  final CrashService crash;

  /// The kiosk the signed-in staff member works at (`null` for an account without one).
  final String? kioskId;
  final DateTime Function() _clock;

  StreamSubscription<List<MenuItem>>? _itemsSub;
  StreamSubscription<List<Kiosk>>? _kiosksSub;
  ViewState<List<MenuItem>> _state = const ViewLoading();
  Kiosk? _kiosk;
  SellerMenuFilter _filter = SellerMenuFilter.all;
  final Set<String> _busy = {};

  ViewState<List<MenuItem>> get state => _state;
  DateTime get now => _clock();
  SellerMenuFilter get filter => _filter;

  List<MenuItem> get _items => _state.dataOrNull ?? const [];

  void load() {
    unawaited(_itemsSub?.cancel());
    unawaited(_kiosksSub?.cancel());
    final id = kioskId;
    if (id == null || id.isEmpty) {
      _state = const ViewEmpty(noKioskMessage);
      notifyListeners();
      return;
    }
    _state = const ViewLoading();
    notifyListeners();
    _itemsSub = menu
        .watchMenu(id)
        .listen(
          (items) {
            _state = ViewStateX.fromList(items, emptyMessage: emptyMessage);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'sellerMenu.watchMenu');
            _state = ViewError(error is AppException ? error.message : 'Không tải được thực đơn.');
            notifyListeners();
          },
        );
    _kiosksSub = menu.watchKiosks().listen((kiosks) {
      _kiosk = kiosks.where((k) => k.id == id).firstOrNull;
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => crash.recordNonFatal(error, stack, 'sellerMenu.watchKiosks'));
  }

  String get kioskName => _kiosk?.name ?? '';

  int get availableCount => _items.where((i) => !i.soldOut).length;

  int get soldOutCount => _items.where((i) => i.soldOut).length;

  String get summary => '${_items.length} món · $soldOutCount hết hàng';

  void setFilter(SellerMenuFilter value) {
    if (value == _filter) return;
    _filter = value;
    notifyListeners();
  }

  /// Message for a filter that matches nothing, or `null` when it matches something.
  String? get emptyFilterMessage {
    if (groups.isNotEmpty) return null;
    return switch (_filter) {
      SellerMenuFilter.available => 'Hiện không có món nào đang bán.',
      SellerMenuFilter.soldOut => 'Chưa có món nào hết hàng.',
      SellerMenuFilter.all => emptyMessage,
    };
  }

  /// The items that pass the filter, by category (food, drinks, other), each sorted by name.
  List<MenuGroup> get groups {
    final shown = _items.where(
      (i) => switch (_filter) {
        SellerMenuFilter.all => true,
        SellerMenuFilter.available => !i.soldOut,
        SellerMenuFilter.soldOut => i.soldOut,
      },
    );
    return [
      for (final category in ItemCategory.values)
        if (shown.where((i) => i.category == category).toList() case final items when items.isNotEmpty)
          MenuGroup(
            category: category,
            label: itemCategoryLabel(category),
            items: [...items]..sort((a, b) => a.name.compareTo(b.name)),
          ),
    ];
  }

  /// What the row says about an item: on sale, or why it is sold out and when it is expected back.
  String statusLine(MenuItem item) {
    if (!item.soldOut) return 'Đang bán';
    final reason = item.soldOutReason == null ? 'Hết hàng' : soldOutReasonLabel(item.soldOutReason!);
    final back = item.availableAgainAt;
    if (back == null) return reason;
    if (back.isBefore(now)) return '$reason · đã quá giờ dự kiến, bật lại khi có hàng';
    return '$reason · dự kiến có lại lúc ${formatTime(back)}';
  }

  /// The switch of this item is working; it cannot be flipped again until the write is done.
  bool isBusy(String itemId) => _busy.contains(itemId);

  Future<Result<void>> markSoldOut(MenuItem item, {required SoldOutReason reason, Duration? backIn}) =>
      _write(item, soldOut: true, reason: reason, backAt: backIn == null ? null : now.add(backIn));

  Future<Result<void>> markAvailable(MenuItem item) => _write(item, soldOut: false);

  Future<Result<void>> _write(MenuItem item, {required bool soldOut, SoldOutReason? reason, DateTime? backAt}) async {
    if (!_busy.add(item.id)) return const Result.ok(null);
    notifyListeners();
    try {
      final result = await menu.setSoldOut(item.id, soldOut, reason: reason, availableAgainAt: backAt);
      if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'sellerMenu.setSoldOut');
      return result;
    } finally {
      _busy.remove(item.id);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_itemsSub?.cancel());
    unawaited(_kiosksSub?.cancel());
    super.dispose();
  }
}
