// Test fakes: the stream controllers live as long as the test.
// ignore_for_file: close_sinks

import 'dart:async';

import 'package:breakbite_core/data/repositories/announcement_repository.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/data/services/auth_service.dart';
import 'package:breakbite_core/data/services/connectivity_service.dart';
import 'package:breakbite_core/data/services/remote_config_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

const staff = AppUser(uid: 's1', displayName: 'Hạnh', role: UserRole.staff, kioskId: 'k1', email: 's1@fpt.edu.vn');
const admin = AppUser(uid: 'a1', displayName: 'Admin', role: UserRole.admin, email: 'a1@fpt.edu.vn');
const customer = AppUser(uid: 'u1', displayName: 'Quân', role: UserRole.user, email: 'u1@fpt.edu.vn');
const staffWithoutKiosk = AppUser(uid: 's0', displayName: 'Nam', role: UserRole.staff, email: 's0@fpt.edu.vn');

class FakeAuthService implements AuthService {
  FakeAuthService({this.nextUser = staff});

  AppUser nextUser;
  final _users = StreamController<AppUser?>.broadcast();
  int signOuts = 0;

  void emit(AppUser? user) => _users.add(user);

  @override
  Stream<AppUser?> authStateChanges() => _users.stream;

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    emit(nextUser);
    return Result.ok(nextUser);
  }

  @override
  Future<Result<void>> signOut() async {
    signOuts++;
    emit(null);
    return const Result.ok(null);
  }
}

Order order(String id, {OrderStatus status = OrderStatus.pending, DateTime? createdAt, int total = 39000}) => Order(
  id: id,
  uid: 'u1',
  items: const [CartItem(itemId: 'k1-tacos', name: 'Combo Tacos', priceVnd: 39000, quantity: 1)],
  totalVnd: total,
  paymentMethod: PaymentMethod.momo,
  status: status,
  kioskId: 'k1',
  createdAt: createdAt ?? DateTime(2026, 11, 12, 9, 30),
  orderCode: '#A-$id',
  customerName: 'Quân',
);

class FakeOrderRepository implements OrderRepository {
  final queue = StreamController<List<Order>>.broadcast();
  final accepted = <(String, Duration)>[];
  final rejected = <(String, String)>[];
  Result<KioskStats> stats = const Result.ok(KioskStats.empty);
  DateTime? statsSince;

  final watchedKiosks = <String>[];

  @override
  Stream<List<Order>> watchKioskQueue(String kioskId) {
    watchedKiosks.add(kioskId);
    return queue.stream;
  }

  @override
  Future<Result<void>> accept(Order order, {required Duration readyIn}) async {
    accepted.add((order.id, readyIn));
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> reject(Order order, {required String reason}) async {
    rejected.add((order.id, reason));
    return const Result.ok(null);
  }

  @override
  Future<Result<KioskStats>> kioskStats(String kioskId, {required DateTime since}) async {
    statsSince = since;
    return stats;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class FakeMenuRepository implements MenuRepository {
  final menu = StreamController<List<MenuItem>>.broadcast();
  final kiosks = StreamController<List<Kiosk>>.broadcast();
  final saved = <MenuItem>[];
  final archived = <(String, bool)>[];
  bool? lastIncludeArchived;

  @override
  Stream<List<MenuItem>> watchMenu(String kioskId, {bool includeArchived = false}) {
    lastIncludeArchived = includeArchived;
    return menu.stream;
  }

  @override
  Stream<List<Kiosk>> watchKiosks() => kiosks.stream;

  @override
  Future<Result<String>> upsertItem(MenuItem item) async {
    if (item.name.isEmpty) return const Result.error(ValidationException('Nhập tên món.'));
    saved.add(item);
    return Result.ok(item.id.isEmpty ? '${item.kioskId}-new' : item.id);
  }

  @override
  Future<Result<void>> setArchived(String id, bool archived) async {
    this.archived.add((id, archived));
    return const Result.ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class FakeAnnouncementRepository implements AnnouncementRepository {
  final all = StreamController<List<Announcement>>.broadcast();
  final published = StreamController<List<Announcement>>.broadcast();
  final created = <({String title, String body, String createdBy, bool publish, String? kioskId})>[];
  final statuses = <(String, AnnouncementStatus)>[];

  @override
  Stream<List<Announcement>> watchAll() => all.stream;

  @override
  Stream<List<Announcement>> watchPublished() => published.stream;

  @override
  Future<Result<String>> create({
    required String title,
    required String body,
    required String createdBy,
    required bool publish,
    String? kioskId,
  }) async {
    created.add((title: title, body: body, createdBy: createdBy, publish: publish, kioskId: kioskId));
    return const Result.ok('n1');
  }

  @override
  Future<Result<void>> setStatus(String id, AnnouncementStatus status) async {
    statuses.add((id, status));
    return const Result.ok(null);
  }
}

MenuItem item(String dishId, {bool soldOut = false, bool archived = false, String? name}) => MenuItem(
  id: 'k1-$dishId',
  dishId: dishId,
  kioskId: 'k1',
  name: name ?? dishId,
  priceVnd: 20000,
  category: ItemCategory.food,
  prepMinutes: 3,
  soldOut: soldOut,
  archived: archived,
);

/// Lets stream events and async commands settle.
Future<void> settle() => Future<void>.delayed(Duration.zero);

class FakeAnalytics implements AnalyticsService {
  final events = <(String, Map<String, Object>?)>[];
  String? userId;

  Iterable<Map<String, Object>?> paramsOf(String name) => events.where((e) => e.$1 == name).map((e) => e.$2);

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async => events.add((name, parameters));

  @override
  Future<void> setUserId(String? uid) async => userId = uid;
}

class FakeRemoteConfig implements RemoteConfigService {
  FakeRemoteConfig([Map<String, Object>? values]) : values = {...RemoteKeys.defaults, ...?values};

  final Map<String, Object> values;
  final updates = StreamController<Set<String>>.broadcast();

  /// Changes a value the way a console publish does: the new value, then the update event.
  void publish(String key, Object value) {
    values[key] = value;
    updates.add({key});
  }

  @override
  Future<void> fetchAndActivate() async {}

  @override
  Stream<Set<String>> watchUpdates() => updates.stream;

  @override
  bool getBool(String key) => values[key] as bool;

  @override
  int getInt(String key) => values[key] as int;

  @override
  String getString(String key) => '${values[key]}';

  @override
  RemoteValueSource sourceOf(String key) => RemoteValueSource.inApp;

  @override
  DateTime? get lastFetchedAt => null;
}

class FakeConnectivity implements ConnectivityService {
  FakeConnectivity({this.online = true});

  bool online;
  final _changes = StreamController<bool>.broadcast();

  void set(bool value) {
    online = value;
    _changes.add(value);
  }

  @override
  Stream<bool> watchOnline() => _changes.stream;

  @override
  Future<bool> check() async => online;
}
