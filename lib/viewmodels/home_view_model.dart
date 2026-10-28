import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'view_state.dart';

/// Mẫu ViewModel cho màn tải dữ liệu (S02 Trang chủ): có đủ loading, empty, error, data.
/// Logic lọc "món nhanh" và giới hạn từ Remote Config nằm ở đây, không nằm trong `build()`.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this.menu,
    required this.cart,
    required this.remoteConfig,
    required this.analytics,
    required this.uid,
  }) {
    load();
  }

  final MenuService menu;
  final CartService cart;
  final RemoteConfigService remoteConfig;
  final AnalyticsService analytics;
  final String uid;

  /// Món có thời gian làm dưới ngưỡng này được coi là "nhanh" (Lab 2: dưới 5 phút).
  static const quickMaxMinutes = 5;

  StreamSubscription<List<MenuItem>>? _sub;
  ViewState<List<MenuItem>> _state = const ViewLoading();

  ViewState<List<MenuItem>> get state => _state;

  bool get promoBannerEnabled => remoteConfig.getBool(RemoteKeys.promoBannerEnabled);

  void load() {
    _state = const ViewLoading();
    notifyListeners();
    unawaited(_sub?.cancel());
    _sub = menu.watchMenu().listen(
      (items) {
        final limit = remoteConfig.getInt(RemoteKeys.quickItemsLimit);
        final quick = items.where((e) => !e.soldOut && e.prepMinutes < quickMaxMinutes).take(limit).toList();
        _state = ViewStateX.fromList(quick, emptyMessage: 'Chưa có món nhanh lúc này');
        notifyListeners();
      },
      onError: (Object e) {
        _state = const ViewError('Không tải được thực đơn. Kiểm tra mạng rồi thử lại.');
        notifyListeners();
      },
    );
  }

  Future<void> addToCart(MenuItem item) async {
    await cart.addItem(uid, CartItem(itemId: item.id, name: item.name, priceVnd: item.priceVnd));
    await analytics.logEvent('add_to_cart', {'item_id': item.id, 'quantity': 1, 'source': 'home'});
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
