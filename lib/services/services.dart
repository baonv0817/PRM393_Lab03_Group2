/// Interface của mọi lời gọi ra ngoài. ViewModel chỉ biết các interface này;
/// bản cài đặt Firebase nằm trong `lib/firebase/` (P3), bản giả cho dev và test
/// nằm trong `lib/dev/` và `test/fakes/`.
library;

import '../models/models.dart';

/// Đăng nhập bị người dùng huỷ.
class AuthCancelled implements Exception {
  const AuthCancelled();
}

/// Đăng nhập lỗi (mất mạng, bị từ chối…).
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

abstract interface class AuthService {
  /// `null` khi chưa đăng nhập.
  Stream<AppUser?> authStateChanges();

  /// Ném [AuthCancelled] khi huỷ, [AuthFailure] khi lỗi.
  Future<AppUser> signInWithGoogle();

  Future<void> signOut();
}

abstract interface class MenuService {
  /// Thực đơn của một kiosk: mỗi món thuộc đúng một kiosk (`MenuItem.kioskId`).
  Stream<List<MenuItem>> watchMenu(String kioskId);
  Future<MenuItem?> getItem(String id);
  Stream<List<Kiosk>> watchKiosks();
  Future<Voucher?> getVoucher(String code);

  /// Người bán.
  Future<void> upsertItem(MenuItem item);
  Future<void> setSoldOut(String id, bool soldOut);
}

abstract interface class CartService {
  Stream<List<CartItem>> watchCart(String uid);
  Future<void> addItem(String uid, CartItem item);
  Future<void> setQuantity(String uid, String itemId, int quantity);
  Future<void> clear(String uid);
}

abstract interface class OrderService {
  Future<String> createOrder({
    required String uid,
    required List<CartItem> items,
    required int totalVnd,
    required PaymentMethod method,
    required String kioskId,
  });
  Stream<Order?> watchOrder(String id);
  Stream<List<Order>> watchMyOrders(String uid);
  Future<void> cancelOrder(String id);

  /// Người bán.
  Stream<List<Order>> watchAllOrders();
  Future<void> updateStatus(String id, OrderStatus status);
}

abstract interface class StorageService {
  /// Tải tệp lên `reports/{uid}/{fileName}`; trả URL tải xuống.
  Future<String> uploadReport({
    required String uid,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  });
}

abstract interface class MessagingService {
  /// Xin quyền thông báo (Android 13+). Trả `true` nếu được cấp.
  Future<bool> requestPermission();

  /// Thông báo nhận khi app ở nền trước.
  Stream<AppNotification> foregroundMessages();

  /// Người dùng chạm vào thông báo để mở app (nền hoặc đã tắt).
  Stream<AppNotification> openedMessages();
}

abstract interface class AnalyticsService {
  Future<void> logEvent(String name, [Map<String, Object>? parameters]);
  Future<void> setUserId(String? uid);
}

abstract interface class CrashService {
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});
  Future<void> setUserId(String uid);
  Future<void> setKey(String key, Object value);

  /// Chỉ dùng cho khu demo Firebase.
  void forceTestCrash();
}

/// Khoá Remote Config (khớp `firebase/remote-config-defaults.json`).
abstract final class RemoteKeys {
  static const quickItemsLimit = 'quick_items_limit';
  static const promoBannerEnabled = 'promo_banner_enabled';
  static const pickupSlotEnabled = 'pickup_slot_enabled';
}

abstract interface class RemoteConfigService {
  Future<void> fetchAndActivate();
  int getInt(String key);
  bool getBool(String key);
}
