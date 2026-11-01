import 'dart:convert';

import 'package:breakbite/config/firebase_setup.dart';
import 'package:breakbite/data/repositories/firestore/firestore_cart_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_menu_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_order_repository.dart';
import 'package:breakbite/data/services/firebase/firebase_auth_service.dart';
import 'package:breakbite/data/services/firebase/notification_inbox.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/firebase_options.dart';
import 'package:breakbite/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

late String project;
final host = emulatorHost();

const webEmulatorOptions = FirebaseOptions(
  apiKey: 'emulator-only',
  appId: '1:652236973307:web:0000000000000000000000',
  messagingSenderId: '652236973307',
  projectId: 'breakbite-1315b',
);

Uri _firestore(String path) =>
    Uri.parse('http://$host:$firestoreEmulatorPort/v1/projects/$project/databases/(default)/documents/$path');

Map<String, Object?> _value(Object? value) => switch (value) {
  null => {'nullValue': null},
  final bool flag => {'booleanValue': flag},
  final int number => {'integerValue': '$number'},
  final double number => {'doubleValue': number},
  final String text => {'stringValue': text},
  final DateTime time => {'timestampValue': time.toUtc().toIso8601String()},
  final List<Object?> list => {
    'arrayValue': {'values': list.map(_value).toList()},
  },
  final Map<String, Object?> map => {
    'mapValue': {'fields': map.map((k, v) => MapEntry(k, _value(v)))},
  },
  _ => throw ArgumentError('Unsupported value $value'),
};

Future<void> adminWrite(String path, Map<String, Object?> data) async {
  final response = await http.patch(
    _firestore(path),
    headers: {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'},
    body: jsonEncode({'fields': data.map((k, v) => MapEntry(k, _value(v)))}),
  );
  if (response.statusCode != 200) throw StateError('Seeding $path failed: ${response.body}');
}

Future<void> resetEmulators() async {
  await http.delete(
    Uri.parse('http://$host:$firestoreEmulatorPort/emulator/v1/projects/$project/databases/(default)/documents'),
  );
  await http.delete(Uri.parse('http://$host:$authEmulatorPort/emulator/v1/projects/$project/accounts'));
}

String googleToken(String sub, String name) =>
    jsonEncode({'sub': sub, 'email': '$sub@example.com', 'email_verified': true, 'name': name});

T ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => throw TestFailure('Expected Ok, got $error'),
};

AppException err<T>(Result<T> result) => switch (result) {
  Ok(:final value) => throw TestFailure('Expected an error, got $value'),
  Err(:final error) => error,
};

Future<void> seed() async {
  final now = DateTime.now().toUtc();
  final stamps = {'createdAt': now, 'updatedAt': now};
  await adminWrite('kiosks/q9-t2', {'name': 'Kiosk Q9 · Tầng 2', 'open': true, 'waitMinutes': 6, ...stamps});
  await adminWrite('kiosks/q9-t4', {'name': 'Kiosk Q9 · Tầng 4', 'open': true, 'waitMinutes': 10, ...stamps});
  await adminWrite('kiosks/nvh-t1', {'name': 'Nhà văn hóa SV', 'open': false, 'waitMinutes': 0, ...stamps});
  for (final (kiosk, dish, name, price, category) in [
    ('q9-t2', 'tacos-bo', 'Combo Tacos Bò Phô Mai', 39000, 'food'),
    ('q9-t2', 'tra-dao', 'Trà Đào Chanh Sả', 20000, 'drink'),
    ('q9-t4', 'tra-dao', 'Trà Đào Chanh Sả', 20000, 'drink'),
    ('nvh-t1', 'banh-mi', 'Bánh Mì Chả Lụa Trứng', 22000, 'food'),
  ]) {
    await adminWrite('menu_items/$kiosk-$dish', {
      'kioskId': kiosk,
      'dishId': dish,
      'name': name,
      'searchName': name.toLowerCase(),
      'description': '',
      'priceVnd': price,
      'category': category,
      'prepMinutes': 4,
      'soldOut': false,
      ...stamps,
    });
  }
  await adminWrite('vouchers/BBSTUDENT', {
    'title': 'Giảm 10K',
    'discount': {'type': 'fixed', 'amountVnd': 10000},
    'minOrderVnd': 40000,
    'expiresAt': DateTime.utc(2100),
    'active': true,
    ...stamps,
  });
  for (final (id, hours) in [('slot-a', 2), ('slot-b', 3)]) {
    final start = now.add(Duration(hours: hours));
    await adminWrite('kiosks/q9-t2/slots/$id', {
      'startAt': start,
      'endAt': start.add(const Duration(minutes: 15)),
      'capacity': 2,
      'booked': 0,
      ...stamps,
    });
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore db;
  late FirebaseAuth auth;
  late FirestoreMenuRepository menu;
  late FirestoreCartRepository cart;
  late FirestoreOrderRepository orders;

  FirebaseAuthService authAs(String sub, String name) =>
      FirebaseAuthService(auth: auth, db: db, googleIdToken: () async => googleToken(sub, name));

  late String customerUid;
  late String cashOrderId;
  late String voucherOrderId;

  Future<Order> orderWhere(String id, bool Function(Order order) test) => orders
      .watchOrder(id)
      .where((o) => o != null && test(o))
      .map((o) => o!)
      .first
      .timeout(const Duration(seconds: 15));

  Future<Cart> cartWhere(bool Function(Cart cart) test) =>
      cart.watchCart(customerUid).firstWhere(test).timeout(const Duration(seconds: 15));

  Future<int> booked(String slot) async =>
      ((await db.doc('kiosks/q9-t2/slots/$slot').get()).data()!['booked'] as num).toInt();

  setUpAll(() async {
    await Firebase.initializeApp(options: kIsWeb ? webEmulatorOptions : DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestoreEmulatorPort);
    await FirebaseAuth.instance.useAuthEmulator(host, authEmulatorPort);
    project = Firebase.app().options.projectId;
    db = FirebaseFirestore.instance;
    auth = FirebaseAuth.instance;
    menu = FirestoreMenuRepository(db);
    cart = FirestoreCartRepository(db);
    orders = FirestoreOrderRepository(db);
    await resetEmulators();
    await seed();
  });

  testWidgets('customer: Google sign-in creates users/{uid} with role user and server timestamps', (tester) async {
    final service = authAs('customer-1', 'Nguyễn Minh Quân');
    final user = ok(await service.signInWithGoogle());
    customerUid = user.uid;
    expect(user.role, UserRole.user);
    expect(user.displayName, 'Nguyễn Minh Quân');
    final profile = (await db.doc('users/$customerUid').get()).data()!;
    expect(profile['role'], 'user');
    expect(profile['createdAt'], isA<Timestamp>());
    final emitted = await service.authStateChanges().firstWhere((u) => u != null);
    expect(emitted!.uid, customerUid);
  });

  testWidgets('customer: menu, kiosks and vouchers load; an unknown code is not found', (tester) async {
    final items = await menu.watchMenu('q9-t2').first;
    expect(items.map((e) => e.dishId), ['tacos-bo', 'tra-dao']);
    expect((await menu.watchKiosks().first).length, 3);
    expect(ok(await menu.getVoucher(' bbstudent ')).discount, isA<FixedDiscount>());
    expect(err(await menu.getVoucher('NOPE99')), isA<NotFoundException>());
    expect(ok(await menu.getItems(['q9-t2-tacos-bo', 'missing'])).keys, ['q9-t2-tacos-bo']);
  });

  testWidgets('customer: the cart is created, edited and refuses items of another kiosk', (tester) async {
    const tacos = CartItem(itemId: 'q9-t2-tacos-bo', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000);
    const tea = CartItem(itemId: 'q9-t2-tra-dao', name: 'Trà Đào Chanh Sả', priceVnd: 20000);
    ok(await cart.addItem(customerUid, kioskId: 'q9-t2', item: tacos));
    ok(await cart.addItem(customerUid, kioskId: 'q9-t2', item: tea));
    ok(await cart.addItem(customerUid, kioskId: 'q9-t2', item: tea));
    ok(await cart.setNote(customerUid, 'q9-t2-tacos-bo', 'Ít cay'));
    ok(await cart.setVoucher(customerUid, 'bbstudent'));
    final slot = PickupSlot(id: 'slot-a', startAt: DateTime.now(), endAt: DateTime.now(), capacity: 2, booked: 0);
    ok(await cart.setPickup(customerUid, slot));
    final other = err(
      await cart.addItem(
        customerUid,
        kioskId: 'q9-t4',
        item: const CartItem(itemId: 'q9-t4-tra-dao', name: 'Trà', priceVnd: 20000),
      ),
    );
    expect(other, isA<ValidationException>());
    expect(other.message, FirestoreCartRepository.otherKioskMessage);

    final current = await cartWhere((c) => c.itemCount == 3 && c.pickupSlotId != null);
    expect(current.kioskId, 'q9-t2');
    expect(current.itemCount, 3);
    expect(current.voucherCode, 'BBSTUDENT');
    expect(current.pickupSlotId, 'slot-a');
    expect(current.items.first.note, 'Ít cay');
    final stored = (await db.doc('carts/$customerUid').get()).data()!;
    expect(stored['createdAt'], isA<Timestamp>());

    ok(await cart.setQuantity(customerUid, 'q9-t2-tra-dao', 0));
    expect((await cartWhere((c) => c.itemCount == 1)).items.single.itemId, 'q9-t2-tacos-bo');
  });

  testWidgets('customer: placing an order writes the order, deletes the cart and books the slot in one go', (
    tester,
  ) async {
    final current = await cartWhere((c) => c.pickupSlotId != null);
    voucherOrderId = ok(
      await orders.placeOrder(
        OrderDraft(
          uid: customerUid,
          customerName: 'Quân N.',
          kioskId: 'q9-t2',
          kioskName: 'Kiosk Q9 · Tầng 2',
          items: const [
            CartItem(itemId: 'q9-t2-tacos-bo', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000),
            CartItem(itemId: 'q9-t2-tra-dao', name: 'Trà Đào Chanh Sả', priceVnd: 20000),
          ],
          paymentMethod: PaymentMethod.momo,
          voucherCode: current.voucherCode,
          pickupSlotId: current.pickupSlotId,
          note: 'Lấy giờ ra chơi',
        ),
      ),
    );
    final order = (await orders.watchOrder(voucherOrderId).firstWhere((o) => o != null))!;
    expect(order.subtotalVnd, 59000);
    expect(order.discountVnd, 10000);
    expect(order.totalVnd, 49000);
    expect(order.paymentStatus, PaymentStatus.paid);
    expect(order.pickupCode, hasLength(6));
    expect(order.orderCode, voucherOrderId.substring(0, 6).toUpperCase());
    expect((await db.doc('carts/$customerUid').get()).exists, isFalse);
    expect(await booked('slot-a'), 1);
  });

  testWidgets('customer: orders that the rules would refuse fail early with a readable message', (tester) async {
    OrderDraft draft({String kioskId = 'q9-t2', String? voucher, String itemId = 'q9-t2-tra-dao'}) => OrderDraft(
      uid: customerUid,
      customerName: 'Quân N.',
      kioskId: kioskId,
      kioskName: kioskId,
      items: [CartItem(itemId: itemId, name: 'Trà', priceVnd: 20000)],
      paymentMethod: PaymentMethod.cash,
      voucherCode: voucher,
    );
    final closed = err(await orders.placeOrder(draft(kioskId: 'nvh-t1', itemId: 'nvh-t1-banh-mi')));
    expect(closed.message, contains('đang đóng cửa'));
    final belowMinimum = err(await orders.placeOrder(draft(voucher: 'BBSTUDENT')));
    expect(belowMinimum.message, 'Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT.');
    final unknown = err(await orders.placeOrder(draft(voucher: 'NOPE99')));
    expect(unknown, isA<NotFoundException>());
  });

  testWidgets('customer: a pending order can be edited, moved to another slot and cancelled', (tester) async {
    final order = (await orders.watchOrder(voucherOrderId).first)!;
    ok(
      await orders.editPendingOrder(
        order,
        items: const [CartItem(itemId: 'q9-t2-tacos-bo', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000, quantity: 2)],
        voucherCode: 'BBSTUDENT',
        pickupSlotId: 'slot-b',
      ),
    );
    final edited = await orderWhere(voucherOrderId, (o) => o.totalVnd == 68000);
    expect(edited.totalVnd, 68000);
    expect(edited.pickupSlotId, 'slot-b');
    expect(edited.note, '');
    expect(await booked('slot-a'), 0);
    expect(await booked('slot-b'), 1);

    ok(await orders.cancelMyOrder(edited, reason: 'Đổi ý'));
    final cancelled = await orderWhere(voucherOrderId, (o) => o.status == OrderStatus.cancelled);
    expect(cancelled.status, OrderStatus.cancelled);
    expect(cancelled.cancelledBy, CancelledBy.customer);
    expect(cancelled.cancelledAt, isNotNull);
    expect(await booked('slot-b'), 0);
    expect(err(await orders.cancelMyOrder(cancelled)), isA<ValidationException>());
  });

  testWidgets('customer: lists, counts and pages only their own orders; cannot act as staff', (tester) async {
    cashOrderId = ok(
      await orders.placeOrder(
        OrderDraft(
          uid: customerUid,
          customerName: 'Quân N.',
          kioskId: 'q9-t2',
          kioskName: 'Kiosk Q9 · Tầng 2',
          items: const [CartItem(itemId: 'q9-t2-tacos-bo', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000)],
          paymentMethod: PaymentMethod.cash,
        ),
      ),
    );
    await orders.placeOrder(
      OrderDraft(
        uid: customerUid,
        customerName: 'Quân N.',
        kioskId: 'q9-t2',
        kioskName: 'Kiosk Q9 · Tầng 2',
        items: const [CartItem(itemId: 'q9-t2-tra-dao', name: 'Trà Đào Chanh Sả', priceVnd: 20000)],
        paymentMethod: PaymentMethod.vnpay,
      ),
    );
    expect(ok(await orders.countMyOrders(customerUid)), 3);
    final first = ok(await orders.fetchMyOrders(customerUid, limit: 2));
    expect(first.items, hasLength(2));
    expect(first.hasMore, isTrue);
    final rest = ok(await orders.fetchMyOrders(customerUid, limit: 2, after: first.next));
    expect(rest.items.single.id, voucherOrderId);
    expect((await orders.watchMyActiveOrders(customerUid).first).map((o) => o.id), contains(cashOrderId));

    final cashOrder = (await orders.watchOrder(cashOrderId).first)!;
    expect(cashOrder.paymentStatus, PaymentStatus.unpaid);
    expect(err(await orders.accept(cashOrder, readyIn: const Duration(minutes: 5))), isA<PermissionDeniedException>());
    expect(err(await menu.setSoldOut('q9-t2-tacos-bo', true)), isA<PermissionDeniedException>());

    await saveToInbox(
      db,
      customerUid,
      const RemoteMessage(
        messageId: 'm-1',
        data: {'orderId': 'o-1', 'status': 'ready'},
        notification: RemoteNotification(title: 'Đơn đã sẵn sàng', body: 'Mời bạn tới quầy'),
      ),
    );
    await saveToInbox(
      db,
      customerUid,
      const RemoteMessage(messageId: 'm-2', data: {'orderId': 'o-1', 'status': 'ready'}),
    );
    final inbox = await db.collection('users/$customerUid/notifications').get();
    expect(inbox.docs.map((d) => d.id), ['o-1_ready']);

    ok(await authAs('customer-1', 'Nguyễn Minh Quân').signOut());
    expect(auth.currentUser, isNull);
  });

  testWidgets('staff: the role set by an admin arrives live; the kiosk queue is processed step by step', (
    tester,
  ) async {
    final service = authAs('staff-1', 'Cô Hạnh');
    final staff = ok(await service.signInWithGoogle());
    expect(staff.role, UserRole.user);
    final now = DateTime.now().toUtc();
    await adminWrite('users/${staff.uid}', {
      'displayName': 'Cô Hạnh',
      'email': 'staff-1@example.com',
      'role': 'staff',
      'kioskId': 'q9-t2',
      'createdAt': now,
      'updatedAt': now,
    });
    final promoted = await service.authStateChanges().firstWhere((u) => u?.role == UserRole.staff);
    expect(promoted!.kioskId, 'q9-t2');

    final queue = await orders.watchKioskQueue('q9-t2').first;
    expect(queue.map((o) => o.id), contains(cashOrderId));
    final pending = queue.firstWhere((o) => o.id == cashOrderId);
    expect(err(await orders.markReady(pending)), isA<ValidationException>());

    ok(await orders.accept(pending, readyIn: const Duration(minutes: 5)));
    final preparing = await orderWhere(cashOrderId, (o) => o.status == OrderStatus.preparing);
    expect(preparing.status, OrderStatus.preparing);
    expect(preparing.readyBy!.isAfter(DateTime.now()), isTrue);

    ok(await orders.markReady(preparing));
    final ready = await orderWhere(cashOrderId, (o) => o.status == OrderStatus.ready);
    expect(ready.prepSeconds, greaterThanOrEqualTo(0));
    expect(ok(await orders.findReadyByPickupCode('q9-t2', ready.pickupCode)).map((o) => o.id), contains(cashOrderId));

    ok(await orders.deliver(ready));
    final delivered = await orderWhere(cashOrderId, (o) => o.status == OrderStatus.delivered);
    expect(delivered.status, OrderStatus.delivered);
    expect(delivered.paymentStatus, PaymentStatus.paid);

    final other = queue.firstWhere((o) => o.id != cashOrderId && o.status == OrderStatus.pending);
    expect(err(await orders.reject(other, reason: '  ')), isA<ValidationException>());
    ok(await orders.reject(other, reason: 'Hết nguyên liệu'));
    final rejected = await orderWhere(other.id, (o) => o.status == OrderStatus.cancelled);
    expect(rejected.cancelledBy, CancelledBy.staff);
    expect(rejected.cancelReason, 'Hết nguyên liệu');
  });

  testWidgets('staff: menu items are created, edited and marked sold out only at their own kiosk', (tester) async {
    const draft = MenuItem(
      id: '',
      name: 'Bánh Flan Caramel',
      priceVnd: 15000,
      category: ItemCategory.other,
      prepMinutes: 1,
      kioskId: 'q9-t2',
    );
    final id = ok(await menu.upsertItem(draft));
    expect(id, 'q9-t2-banh-flan-caramel');
    final created = ok(await menu.getItem(id));
    ok(
      await menu.upsertItem(
        MenuItem(
          id: id,
          name: 'Bánh Flan Caramel',
          priceVnd: 18000,
          category: ItemCategory.other,
          prepMinutes: 1,
          kioskId: 'q9-t2',
          dishId: created.dishId,
        ),
      ),
    );
    expect(ok(await menu.getItem(id)).priceVnd, 18000);
    final data = (await db.doc('menu_items/$id').get()).data()!;
    expect(data['searchName'], 'banh flan caramel');
    expect(data['createdAt'], isA<Timestamp>());

    ok(await menu.setSoldOut(id, true));
    expect(ok(await menu.getItem(id)).soldOut, isTrue);
    expect(err(await menu.setSoldOut('q9-t4-tra-dao', true)), isA<PermissionDeniedException>());
    expect(err(await menu.upsertItem(draft.copyWith(priceVnd: 0))), isA<ValidationException>());
  });
}
