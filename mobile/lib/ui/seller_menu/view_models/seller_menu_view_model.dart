import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
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

  /// The two times K09 offers as "Có lại lúc": the first half hour at least 15 minutes from now, and the one
  /// after it. The third choice, "Hết ngày", has no time.
  List<DateTime> get backOptions {
    final earliest = now.add(const Duration(minutes: 15));
    // The first half hour that is not before [earliest], seconds included.
    var first = DateTime(earliest.year, earliest.month, earliest.day, earliest.hour);
    while (first.isBefore(earliest)) {
      first = first.add(const Duration(minutes: 30));
    }
    return [first, first.add(const Duration(minutes: 30))];
  }

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

  /// The staff member works at a kiosk, so items can be added to it.
  bool get hasKiosk => kioskId != null && kioskId!.isNotEmpty;

  /// The "add" button is shown on a menu that has items; an empty menu offers it in its own message.
  bool get canAdd => hasKiosk && _state is ViewData<List<MenuItem>>;

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

  /// What a row says after the price: "Còn hàng", or "Hết" with the time it is expected back.
  String statusLine(MenuItem item) {
    if (!item.soldOut) return 'Còn hàng';
    final back = item.availableAgainAt;
    if (back == null) return 'Hết';
    if (back.isBefore(now)) return 'Hết · quá giờ dự kiến';
    return 'Hết · có lại ${formatTime(back)}';
  }

  /// The switch of this item is working; it cannot be flipped again until the write is done.
  bool isBusy(String itemId) => _busy.contains(itemId);

  Future<Result<void>> markSoldOut(MenuItem item, {required SoldOutReason reason, DateTime? backAt}) =>
      _write(item, soldOut: true, reason: reason, backAt: backAt);

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
