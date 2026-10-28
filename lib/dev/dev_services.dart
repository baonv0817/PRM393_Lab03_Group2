/// CHỈ DÙNG KHI PHÁT TRIỂN VÀ TEST: service giả giữ dữ liệu trong bộ nhớ để dựng
/// màn hình khi Firebase chưa nối xong. Bật bằng `--dart-define=USE_DEV_SERVICES=true`.
///
/// QUAN TRỌNG: handout cấm dữ liệu cứng hay mock trong bản nộp. Trước khi nộp phải
/// xoá thư mục `lib/dev/` (task T83) và gỡ chỗ gọi trong `lib/main.dart`.
library;

import 'dart:async';

import '../models/models.dart';
import '../services/app_services.dart';
import '../services/services.dart';

class _Live<T> {
  _Live(this._value);

  T _value;
  final _controller = StreamController<T>.broadcast();

  T get value => _value;

  Stream<T> get stream async* {
    yield _value;
    yield* _controller.stream;
  }

  void set(T v) {
    _value = v;
    _controller.add(v);
  }
}

class DevAuthService implements AuthService {
  DevAuthService({this.role = UserRole.user, bool signedIn = false})
      : _user = _Live<AppUser?>(signedIn ? _make(role) : null);

  final UserRole role;
  final _Live<AppUser?> _user;

  static AppUser _make(UserRole role) => AppUser(
        uid: role == UserRole.user ? 'dev-user' : 'dev-staff',
        displayName: role == UserRole.user ? 'Minh Quân' : 'Cô Hạnh',
        role: role,
      );

  @override
  Stream<AppUser?> authStateChanges() => _user.stream;

  @override
  Future<AppUser> signInWithGoogle() async {
    final user = _make(role);
    _user.set(user);
    return user;
  }

  @override
  Future<void> signOut() async => _user.set(null);
}

class DevMenuService implements MenuService {
  final _menu = _Live<List<MenuItem>>(const [
    MenuItem(id: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000, category: 'Tacos', prepMinutes: 4),
    MenuItem(id: 'm2', name: 'Mì Trộn Gà Cay Hàn Quốc', priceVnd: 35000, category: 'Mì trộn', prepMinutes: 5),
    MenuItem(id: 'm3', name: 'Trà Đào Chanh Sả', priceVnd: 20000, category: 'Đồ uống', prepMinutes: 2),
    MenuItem(id: 'm4', name: 'Tacos Gà Giòn Sốt Cay', priceVnd: 35000, category: 'Tacos', prepMinutes: 4, soldOut: true),
  ]);
  final _kiosks = _Live<List<Kiosk>>(const [
    Kiosk(id: 'q9-t2', name: 'Kiosk Q9 · Tầng 2', open: true, waitMinutes: 6),
    Kiosk(id: 'q9-t4', name: 'Kiosk Q9 · Tầng 4', open: true, waitMinutes: 10),
    Kiosk(id: 'nvh-t1', name: 'Nhà văn hóa SV · Tầng 1', open: false, waitMinutes: 0),
  ]);

  @override
  Stream<List<MenuItem>> watchMenu() => _menu.stream;

  @override
  Future<MenuItem?> getItem(String id) async => _menu.value.where((e) => e.id == id).firstOrNull;

  @override
  Stream<List<Kiosk>> watchKiosks() => _kiosks.stream;

  @override
  Future<Voucher?> getVoucher(String code) async => switch (code) {
        'BBSTUDENT' => Voucher(code: code, discountVnd: 10000, expiresAt: DateTime(2100), minOrderVnd: 40000),
        'BB20' => Voucher(code: code, discountVnd: 20000, expiresAt: DateTime(2020), minOrderVnd: 0),
        _ => null,
      };

  @override
  Future<void> upsertItem(MenuItem item) async {
    final list = [..._menu.value];
    final i = list.indexWhere((e) => e.id == item.id);
    i == -1 ? list.add(item) : list[i] = item;
    _menu.set(list);
  }

  @override
  Future<void> setSoldOut(String id, bool soldOut) async {
    _menu.set([
      for (final e in _menu.value)
        e.id == id
            ? MenuItem(
                id: e.id,
                name: e.name,
                priceVnd: e.priceVnd,
                category: e.category,
                prepMinutes: e.prepMinutes,
                soldOut: soldOut)
            : e,
    ]);
  }
}

class DevCartService implements CartService {
  final _carts = <String, _Live<List<CartItem>>>{};

  _Live<List<CartItem>> _of(String uid) => _carts.putIfAbsent(uid, () => _Live(const []));

  @override
  Stream<List<CartItem>> watchCart(String uid) => _of(uid).stream;

  @override
  Future<void> addItem(String uid, CartItem item) async {
    final cart = _of(uid);
    final list = [...cart.value];
    final i = list.indexWhere((e) => e.itemId == item.itemId);
    i == -1 ? list.add(item) : list[i] = list[i].copyWith(quantity: list[i].quantity + item.quantity);
    cart.set(list);
  }

  @override
  Future<void> setQuantity(String uid, String itemId, int quantity) async {
    final cart = _of(uid);
    cart.set([
      for (final e in cart.value)
        if (e.itemId != itemId) e else if (quantity > 0) e.copyWith(quantity: quantity),
    ]);
  }

  @override
  Future<void> clear(String uid) async => _of(uid).set(const []);
}

class DevOrderService implements OrderService {
  final _orders = _Live<List<Order>>(const []);
  var _seq = 203;

  @override
  Future<String> createOrder({
    required String uid,
    required List<CartItem> items,
    required int totalVnd,
    required PaymentMethod method,
    required String kioskId,
  }) async {
    final id = 'A-${++_seq}';
    _orders.set([
      ..._orders.value,
      Order(
        id: id,
        uid: uid,
        items: items,
        totalVnd: totalVnd,
        paymentMethod: method,
        status: OrderStatus.pending,
        kioskId: kioskId,
        createdAt: DateTime.now(),
      ),
    ]);
    return id;
  }

  @override
  Stream<Order?> watchOrder(String id) => _orders.stream.map((l) => l.where((o) => o.id == id).firstOrNull);

  @override
  Stream<List<Order>> watchMyOrders(String uid) => _orders.stream.map((l) => l.where((o) => o.uid == uid).toList());

  @override
  Future<void> cancelOrder(String id) => updateStatus(id, OrderStatus.cancelled);

  @override
  Stream<List<Order>> watchAllOrders() => _orders.stream;

  @override
  Future<void> updateStatus(String id, OrderStatus status) async {
    _orders.set([
      for (final o in _orders.value)
        o.id == id
            ? Order(
                id: o.id,
                uid: o.uid,
                items: o.items,
                totalVnd: o.totalVnd,
                paymentMethod: o.paymentMethod,
                status: status,
                kioskId: o.kioskId,
                createdAt: o.createdAt)
            : o,
    ]);
  }
}

class DevStorageService implements StorageService {
  @override
  Future<String> uploadReport({
    required String uid,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    for (var i = 1; i <= 4; i++) {
      onProgress?.call(i / 4);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return 'https://storage.invalid/reports/$uid/$fileName';
  }
}

class DevMessagingService implements MessagingService {
  final _foreground = StreamController<AppNotification>.broadcast();
  final _opened = StreamController<AppNotification>.broadcast();

  void emitForeground(AppNotification n) => _foreground.add(n);
  void emitOpened(AppNotification n) => _opened.add(n);

  @override
  Future<bool> requestPermission() async => true;

  @override
  Stream<AppNotification> foregroundMessages() => _foreground.stream;

  @override
  Stream<AppNotification> openedMessages() => _opened.stream;
}

class DevAnalyticsService implements AnalyticsService {
  final events = <({String name, Map<String, Object>? params})>[];
  String? userId;

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async =>
      events.add((name: name, params: parameters));

  @override
  Future<void> setUserId(String? uid) async => userId = uid;
}

class DevCrashService implements CrashService {
  final errors = <Object>[];
  final keys = <String, Object>{};

  @override
  void forceTestCrash() => throw StateError('Test crash (dev)');

  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason}) async => errors.add(error);

  @override
  Future<void> setKey(String key, Object value) async => keys[key] = value;

  @override
  Future<void> setUserId(String uid) async => keys['uid'] = uid;
}

class DevRemoteConfigService implements RemoteConfigService {
  final values = <String, Object>{
    RemoteKeys.quickItemsLimit: 5,
    RemoteKeys.promoBannerEnabled: true,
    RemoteKeys.pickupSlotEnabled: true,
  };

  @override
  Future<void> fetchAndActivate() async {}

  @override
  int getInt(String key) => (values[key] as int?) ?? 0;

  @override
  bool getBool(String key) => (values[key] as bool?) ?? false;
}

AppServices createDevServices({UserRole role = UserRole.user, bool signedIn = false}) => AppServices(
      auth: DevAuthService(role: role, signedIn: signedIn),
      menu: DevMenuService(),
      cart: DevCartService(),
      orders: DevOrderService(),
      storage: DevStorageService(),
      messaging: DevMessagingService(),
      analytics: DevAnalyticsService(),
      crash: DevCrashService(),
      remoteConfig: DevRemoteConfigService(),
    );
