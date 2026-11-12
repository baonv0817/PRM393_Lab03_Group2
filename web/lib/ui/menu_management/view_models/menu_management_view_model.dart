import 'dart:async';

import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/data/services/analytics_events.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/menu_item.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:breakbite_core/utils/text.dart';
import 'package:flutter/foundation.dart';

enum MenuFilter { onSale, soldOut, archived, all }

/// What the editor dialog sends back: a new item (no id) or the edited fields of an existing one.
class MenuItemInput {
  const MenuItemInput({
    required this.name,
    required this.priceVnd,
    required this.category,
    required this.prepMinutes,
    this.description = '',
    this.imageUrl,
    this.soldOut = false,
  });

  final String name;
  final int priceVnd;
  final ItemCategory category;
  final int prepMinutes;
  final String description;
  final String? imageUrl;
  final bool soldOut;
}

/// W02 Management: list, search, create, edit and archive the kiosk's menu items, the entity the mobile menu
/// (S03), search (S28) and the seller menu (K08) read. Archived items stay in Firestore (no deletes) and come
/// back with "Khôi phục".
class MenuManagementViewModel extends ChangeNotifier with SafeChangeNotifier {
  MenuManagementViewModel({required this._menu, required this.kioskId, this._analytics}) {
    save = Command1(_save);
    toggleArchived = Command1(_toggleArchived);
    _listen();
  }

  final MenuRepository _menu;
  final AnalyticsService? _analytics;
  final String kioskId;
  StreamSubscription<List<MenuItem>>? _sub;

  late final Command1<String, (MenuItem?, MenuItemInput)> save;
  late final Command1<void, MenuItem> toggleArchived;

  ViewState<List<MenuItem>> _source = const ViewLoading();
  String _query = '';
  MenuFilter _filter = MenuFilter.onSale;

  String get query => _query;
  MenuFilter get filter => _filter;

  /// How many items each filter chip holds.
  Map<MenuFilter, int> get counts {
    final all = _source.dataOrNull ?? const <MenuItem>[];
    return {for (final f in MenuFilter.values) f: all.where((i) => _matchesFilter(i, f)).length};
  }

  /// The items after the filter chip and the search box.
  ViewState<List<MenuItem>> get state => switch (_source) {
    ViewData(:final data) => ViewStateX.fromList(
      data.where((i) => _matchesFilter(i, _filter) && _matchesQuery(i)).toList(),
      emptyMessage: _query.isEmpty ? _emptyMessage : 'Không có món nào khớp "$_query".',
    ),
    ViewEmpty() => const ViewEmpty('Kiosk chưa có món nào. Bấm "Thêm món" để tạo món đầu tiên.'),
    final other => other,
  };

  String get _emptyMessage => switch (_filter) {
    MenuFilter.onSale => 'Không có món nào đang bán.',
    MenuFilter.soldOut => 'Không có món nào tạm hết.',
    MenuFilter.archived => 'Chưa lưu trữ món nào.',
    MenuFilter.all => 'Kiosk chưa có món nào.',
  };

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void setFilter(MenuFilter value) {
    if (value == _filter) return;
    _filter = value;
    notifyListeners();
  }

  void retry() {
    _sub?.cancel();
    _source = const ViewLoading();
    notifyListeners();
    _listen();
  }

  bool _matchesFilter(MenuItem item, MenuFilter filter) => switch (filter) {
    MenuFilter.onSale => item.orderable,
    MenuFilter.soldOut => item.soldOut && !item.archived,
    MenuFilter.archived => item.archived,
    MenuFilter.all => true,
  };

  bool _matchesQuery(MenuItem item) {
    final q = searchKey(_query.trim());
    return q.isEmpty || searchKey(item.name).contains(q) || item.dishId.contains(q);
  }

  void _listen() {
    _sub = _menu
        .watchMenu(kioskId, includeArchived: true)
        .listen(
          (items) {
            _source = ViewStateX.fromList(items);
            notifyListeners();
          },
          onError: (Object error) {
            _source = ViewError(error is AppException ? error.message : 'Không tải được thực đơn. Thử lại.');
            notifyListeners();
          },
        );
  }

  Future<Result<String>> _save((MenuItem?, MenuItemInput) request) async {
    final (existing, input) = request;
    final item = MenuItem(
      id: existing?.id ?? '',
      dishId: existing?.dishId ?? '',
      kioskId: kioskId,
      name: input.name.trim(),
      priceVnd: input.priceVnd,
      category: input.category,
      prepMinutes: input.prepMinutes,
      description: input.description.trim(),
      imageUrl: (input.imageUrl?.trim().isEmpty ?? true) ? null : input.imageUrl!.trim(),
      soldOut: input.soldOut,
      soldOutReason: input.soldOut ? existing?.soldOutReason : null,
      availableAgainAt: input.soldOut ? existing?.availableAgainAt : null,
      archived: existing?.archived ?? false,
    );
    final result = await _menu.upsertItem(item);
    if (result is Ok) {
      unawaited(
        _analytics?.logEvent(AnalyticsEvents.menuItemSaved, {
          'is_new': existing == null,
          'category': input.category.name,
          'sold_out': input.soldOut,
        }),
      );
    }
    return result;
  }

  Future<Result<void>> _toggleArchived(MenuItem item) async {
    final result = await _menu.setArchived(item.id, !item.archived);
    if (result is Ok) {
      unawaited(_analytics?.logEvent(AnalyticsEvents.menuItemArchived, {'archived': !item.archived}));
    }
    return result;
  }

  @override
  void dispose() {
    _sub?.cancel();
    save.dispose();
    toggleArchived.dispose();
    super.dispose();
  }
}
