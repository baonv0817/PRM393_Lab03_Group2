import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'view_state.dart';

/// Mẫu ViewModel cho màn tải dữ liệu (S02 Trang chủ): có đủ loading, empty, error, data.
/// Logic lọc "món nhanh", chip loại món, giới hạn từ Remote Config, trạng thái kiosk và số món
/// trong giỏ nằm ở đây, không nằm trong `build()`.
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

  /// Món có thời gian làm tối đa ngưỡng này được coi là "nhanh" (Figma S02 hiện cả món 5 phút).
  static const quickMaxMinutes = 5;

  StreamSubscription<List<MenuItem>>? _menuSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  StreamSubscription<List<CartItem>>? _cartSub;

  List<MenuItem> _items = const [];
  ViewState<List<MenuItem>> _state = const ViewLoading();
  Kiosk? _kiosk;
  int _cartCount = 0;
  String? _category;

  /// Danh sách món nhanh đã lọc theo chip đang chọn.
  ViewState<List<MenuItem>> get state => _state;

  bool get promoBannerEnabled => remoteConfig.getBool(RemoteKeys.promoBannerEnabled);

  /// Kiosk đang đặt: kiosk mở cửa đầu tiên, nếu không có thì kiosk đầu tiên (đổi kiosk là S27, P2).
  Kiosk? get kiosk => _kiosk;

  /// Dòng trạng thái dưới tên kiosk, ví dụ "Sẵn sàng · chờ 5–7 phút".
  String? get kioskStatus {
    final k = _kiosk;
    if (k == null) return null;
    if (!k.open) return 'Đang đóng cửa';
    final low = k.waitMinutes > 1 ? k.waitMinutes - 1 : 1;
    return 'Sẵn sàng · chờ $low–${k.waitMinutes + 1} phút';
  }

  /// Tổng số phần trong giỏ (cộng cả số lượng), hiện ở huy hiệu giỏ hàng.
  int get cartCount => _cartCount;

  /// Số thông báo chưa đọc. Chưa có service thông báo (P2, màn S19) nên luôn là 0.
  int get unreadNotifications => 0;

  /// Loại món để làm chip, theo thứ tự xuất hiện trong thực đơn.
  List<String> get categories => {for (final i in _items) i.category}.toList();

  /// Chip đang chọn; `null` là "Tất cả".
  String? get selectedCategory => _category;

  void selectCategory(String? category) {
    if (_category == category) return;
    _category = category;
    _recompute();
  }

  void load() {
    _state = const ViewLoading();
    notifyListeners();
    unawaited(_menuSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_cartSub?.cancel());
    _menuSub = menu.watchMenu().listen(
      (items) {
        _items = items;
        _recompute();
      },
      onError: (Object e) {
        _state = const ViewError('Không tải được thực đơn. Kiểm tra mạng rồi thử lại.');
        notifyListeners();
      },
    );
    // Kiosk và giỏ chỉ làm đẹp phần đầu trang: lỗi thì bỏ qua, không chặn danh sách món.
    _kioskSub = menu.watchKiosks().listen(
      (kiosks) {
        _kiosk = kiosks.where((k) => k.open).firstOrNull ?? kiosks.firstOrNull;
        notifyListeners();
      },
      onError: (Object e) {},
    );
    _cartSub = cart.watchCart(uid).listen(
      (items) {
        _cartCount = items.fold(0, (sum, e) => sum + e.quantity);
        notifyListeners();
      },
      onError: (Object e) {},
    );
  }

  void _recompute() {
    final limit = remoteConfig.getInt(RemoteKeys.quickItemsLimit);
    final quick = _items
        .where((e) => !e.soldOut && e.prepMinutes <= quickMaxMinutes && (_category == null || e.category == _category))
        .take(limit)
        .toList();
    _state = ViewStateX.fromList(
      quick,
      emptyMessage: _category == null ? 'Chưa có món nhanh lúc này' : 'Chưa có món nhanh trong mục này',
    );
    notifyListeners();
  }

  Future<void> addToCart(MenuItem item) async {
    await cart.addItem(uid, CartItem(itemId: item.id, name: item.name, priceVnd: item.priceVnd));
    await analytics.logEvent('add_to_cart', {'item_id': item.id, 'quantity': 1, 'source': 'home'});
  }

  @override
  void dispose() {
    unawaited(_menuSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_cartSub?.cancel());
    super.dispose();
  }
}
