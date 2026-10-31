import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/ui/core/view_state.dart';

/// Mẫu ViewModel cho màn tải dữ liệu (S02 Trang chủ): có đủ loading, empty, error, data.
/// Logic lọc "món nhanh", giới hạn từ Remote Config, trạng thái kiosk, số món trong giỏ và đơn
/// gần đây (để đặt lại) nằm ở đây, không nằm trong `build()`.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this.menu,
    required this.cart,
    required this.orders,
    required this.remoteConfig,
    required this.analytics,
    required this.uid,
  }) {
    load();
  }

  final MenuRepository menu;
  final CartRepository cart;
  final OrderRepository orders;
  final RemoteConfigService remoteConfig;
  final AnalyticsService analytics;
  final String uid;

  /// Món có thời gian làm tối đa ngưỡng này được coi là "nhanh" (Lab 2: bữa nghỉ 15 phút).
  static const quickMaxMinutes = 5;

  StreamSubscription<List<MenuItem>>? _menuSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  StreamSubscription<List<CartItem>>? _cartSub;
  StreamSubscription<List<Order>>? _ordersSub;

  ViewState<List<MenuItem>> _state = const ViewLoading();
  Kiosk? _kiosk;
  int _cartCount = 0;
  Order? _lastOrder;

  /// Danh sách món nhanh.
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

  /// Đơn gần nhất chưa bị huỷ; `null` khi người dùng chưa đặt đơn nào (khi đó không hiện nút Đặt lại).
  Order? get lastOrder => _lastOrder;

  void load() {
    _state = const ViewLoading();
    _kiosk = null; // chọn lại kiosk khi thử lại
    notifyListeners();
    unawaited(_menuSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_cartSub?.cancel());
    unawaited(_ordersSub?.cancel());
    // Chọn kiosk trước rồi mới tải thực đơn của kiosk đó; kiosk đổi thì tải lại thực đơn.
    _kioskSub = menu.watchKiosks().listen(
      (kiosks) {
        final next = kiosks.where((k) => k.open).firstOrNull ?? kiosks.firstOrNull;
        final changed = next?.id != _kiosk?.id;
        _kiosk = next;
        if (next == null) {
          unawaited(_menuSub?.cancel());
          _state = const ViewEmpty('Chưa có kiosk nào đang hoạt động');
        } else if (changed) {
          _watchMenu(next.id);
        }
        notifyListeners();
      },
      onError: (Object e) => _fail(),
    );
    // Giỏ và đơn gần đây chỉ bổ sung cho trang: lỗi thì bỏ qua, không chặn danh sách món.
    _cartSub = cart.watchCart(uid).listen(
      (items) {
        _cartCount = items.fold(0, (sum, e) => sum + e.quantity);
        notifyListeners();
      },
      onError: (Object e) {},
    );
    _ordersSub = orders.watchMyOrders(uid).listen(
      (list) {
        final mine = list.where((o) => o.status != OrderStatus.cancelled).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _lastOrder = mine.firstOrNull;
        notifyListeners();
      },
      onError: (Object e) {},
    );
  }

  void _watchMenu(String kioskId) {
    unawaited(_menuSub?.cancel());
    _state = const ViewLoading();
    _menuSub = menu.watchMenu(kioskId).listen(
      (items) {
        final limit = remoteConfig.getInt(RemoteKeys.quickItemsLimit);
        final quick = items.where((e) => !e.soldOut && e.prepMinutes <= quickMaxMinutes).take(limit).toList();
        _state = ViewStateX.fromList(quick, emptyMessage: 'Chưa có món nhanh lúc này');
        notifyListeners();
      },
      onError: (Object e) => _fail(),
    );
  }

  void _fail() {
    _state = const ViewError('Không tải được thực đơn. Kiểm tra mạng rồi thử lại.');
    notifyListeners();
  }

  Future<void> addToCart(MenuItem item) async {
    await cart.addItem(uid, CartItem(itemId: item.id, name: item.name, priceVnd: item.priceVnd));
    await analytics.logEvent(AnalyticsEvents.addToCart, {'item_id': item.id, 'quantity': 1, 'source': 'home'});
  }

  /// Đặt lại: thêm lại các món của đơn gần nhất vào giỏ. Trả về số dòng món đã thêm (0 nếu chưa có đơn).
  Future<int> reorderLast() async {
    final order = _lastOrder;
    if (order == null) return 0;
    for (final item in order.items) {
      await cart.addItem(uid, item);
    }
    await analytics.logEvent(AnalyticsEvents.reorder, {'order_id': order.id, 'item_count': order.items.length});
    return order.items.length;
  }

  @override
  void dispose() {
    unawaited(_menuSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_cartSub?.cancel());
    unawaited(_ordersSub?.cancel());
    super.dispose();
  }
}
