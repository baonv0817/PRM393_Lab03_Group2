import 'dart:convert';

import 'package:breakbite/config/firebase_setup.dart';
import 'package:breakbite/data/repositories/firestore/firestore_cart_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_favorite_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_incident_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_menu_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_notification_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_order_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_report_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_review_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_slot_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_user_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_voucher_repository.dart';
import 'package:breakbite/data/repositories/review_repository.dart';
import 'package:breakbite/data/services/firebase/firebase_auth_service.dart';
import 'package:breakbite/data/services/firebase/notification_inbox.dart';
import 'package:breakbite/data/services/storage_service.dart';
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

  testWidgets('customer: menu, kiosks, vouchers and upcoming slots load; an unknown code is not found', (tester) async {
    final items = await menu.watchMenu('q9-t2').first;
    expect(items.map((e) => e.dishId), ['tacos-bo', 'tra-dao']);
    expect((await menu.watchKiosks().first).length, 3);
    expect(ok(await menu.getVoucher(' bbstudent ')).discount, isA<FixedDiscount>());
    expect(err(await menu.getVoucher('NOPE99')), isA<NotFoundException>());
    expect(ok(await menu.getItems(['q9-t2-tacos-bo', 'missing'])).keys, ['q9-t2-tacos-bo']);
    final active = await FirestoreVoucherRepository(db).watchActiveVouchers().first;
    expect(active.map((v) => v.code), ['BBSTUDENT']);
    final upcoming = await FirestoreSlotRepository(db).watchUpcomingSlots('q9-t2', from: DateTime.now()).first;
    expect(upcoming.map((s) => s.id), ['slot-a', 'slot-b']);
    expect(upcoming.first.remaining, 2);
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

  testWidgets('customer: profile, default kiosk, payment method and exported files pass the rules', (tester) async {
    final service = authAs('customer-1', 'Nguyễn Minh Quân');
    ok(await service.signInWithGoogle());
    final users = FirestoreUserRepository(db);
    final reports = FirestoreReportRepository(db);
    const wait = Duration(seconds: 15);

    ok(
      await users.saveProfile(
        customerUid,
        displayName: ' Nguyễn  Minh Quân ',
        studentId: 'se183398',
        phone: '+84 912 345 678',
        defaultKioskId: 'q9-t4',
      ),
    );
    ok(await users.setDefaultPaymentMethod(customerUid, PaymentMethod.cash));
    final profile = await users
        .watchProfile(customerUid)
        .firstWhere((p) => p.defaultPaymentMethod == PaymentMethod.cash && p.defaultKioskId == 'q9-t4')
        .timeout(wait);
    expect(profile.displayName, 'Nguyễn Minh Quân');
    expect(profile.studentId, 'SE183398');
    expect(profile.phone, '0912345678');
    final signedIn = await service.authStateChanges().firstWhere((u) => u?.defaultKioskId == 'q9-t4').timeout(wait);
    expect(signedIn!.uid, customerUid);

    expect(
      err(await users.saveProfile(customerUid, displayName: 'Quân', studentId: 'SE12')),
      isA<ValidationException>(),
    );
    await expectLater(
      db.doc('users/$customerUid').update({'defaultKioskId': 'nowhere', 'updatedAt': FieldValue.serverTimestamp()}),
      throwsA(isA<FirebaseException>()),
    );
    ok(await users.saveProfile(customerUid, displayName: 'Quân'));
    final cleared = await users
        .watchProfile(customerUid)
        .firstWhere((p) => p.displayName == 'Quân' && p.defaultKioskId == null)
        .timeout(wait);
    expect(cleared.studentId, isNull);
    expect(cleared.defaultPaymentMethod, PaymentMethod.cash);

    final report = ok(
      await reports.save(
        uid: customerUid,
        fileName: 'breakbite-don-hang.pdf',
        file: const UploadedFile(
          url: 'https://res.cloudinary.com/demo/image/upload/x.pdf',
          publicId: 'breakbite/reports/x',
          sizeBytes: 9148,
        ),
      ),
    );
    expect(report.sizeKb, 9);
    final mine = await reports.watchMine(customerUid).firstWhere((list) => list.isNotEmpty).timeout(wait);
    expect(mine.single.fileName, 'breakbite-don-hang.pdf');
    expect(
      err(
        await reports.save(
          uid: customerUid,
          fileName: 'x.pdf',
          file: const UploadedFile(url: 'http://x', publicId: 'x', sizeBytes: 2048),
        ),
      ),
      isA<ValidationException>(),
    );

    ok(await service.signOut());
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
    // [CR-02] A second "new" item with the same name is refused and does not overwrite the first.
    expect(err(await menu.upsertItem(draft)), isA<ValidationException>());
    expect(ok(await menu.getItem(id)).priceVnd, 18000);
    final data = (await db.doc('menu_items/$id').get()).data()!;
    expect(data['searchName'], 'banh flan caramel');
    expect(data['createdAt'], isA<Timestamp>());

    ok(await menu.setSoldOut(id, true));
    expect(ok(await menu.getItem(id)).soldOut, isTrue);
    expect(err(await menu.setSoldOut('q9-t4-tra-dao', true)), isA<PermissionDeniedException>());
    expect(err(await menu.upsertItem(draft.copyWith(priceVnd: 0))), isA<ValidationException>());
  });

  testWidgets('staff: K10 writes the shop settings and removes the fields that are emptied, only at their own kiosk', (
    tester,
  ) async {
    final until = DateTime.now().add(const Duration(minutes: 30));
    ok(
      await menu.updateKiosk(
        'q9-t2',
        KioskSettings(
          open: true,
          waitMinutes: 9,
          pausedUntil: until,
          maxOrdersPerSlot: 5,
          notice: '  Hết sốt phô mai  ',
          openTime: '06:30',
          closeTime: '17:00',
        ),
      ),
    );
    var data = (await db.doc('kiosks/q9-t2').get()).data()!;
    expect(data['waitMinutes'], 9);
    expect(data['maxOrdersPerSlot'], 5);
    expect(data['notice'], 'Hết sốt phô mai');
    expect((data['openTime'], data['closeTime']), ('06:30', '17:00'));
    expect(data['pausedUntil'], isA<Timestamp>());
    expect(data['name'], 'Kiosk Q9 · Tầng 2', reason: 'the name is not staff\'s to change and is left alone');
    final kiosk = (await menu.watchKiosks().first).firstWhere((k) => k.id == 'q9-t2');
    expect(kiosk.acceptsOrders(DateTime.now()), isFalse, reason: 'paused for 30 minutes');

    ok(await menu.updateKiosk('q9-t2', const KioskSettings(open: true, waitMinutes: 6)));
    data = (await db.doc('kiosks/q9-t2').get()).data()!;
    for (final field in ['pausedUntil', 'maxOrdersPerSlot', 'notice', 'openTime', 'closeTime']) {
      expect(data.containsKey(field), isFalse, reason: '$field was emptied');
    }
    expect(data['waitMinutes'], 6);

    expect(
      err(await menu.updateKiosk('q9-t4', const KioskSettings(open: false, waitMinutes: 1))),
      isA<PermissionDeniedException>(),
    );
    expect(
      err(await menu.updateKiosk('q9-t2', const KioskSettings(open: true, waitMinutes: 121))),
      isA<ValidationException>(),
    );
  });

  testWidgets('staff: K11 counts the shift of their own kiosk on the server and cannot read another kiosk', (
    tester,
  ) async {
    final since = DateTime.now().subtract(const Duration(days: 1));
    final stats = ok(await orders.kioskStats('q9-t2', since: since));
    expect(stats.deliveredCount, greaterThanOrEqualTo(1), reason: 'the cash order was delivered above');
    expect(stats.revenueVnd, greaterThan(0));
    expect(stats.cancelledCount, greaterThanOrEqualTo(1), reason: 'the other order was rejected above');
    expect(stats.averagePrepSeconds, isNotNull);
    expect(stats.averagePrepSeconds, greaterThanOrEqualTo(0));
    expect(stats.ordersByHour.values.fold(0, (a, b) => a + b), greaterThanOrEqualTo(1));
    expect(stats.chartTruncated, isFalse);
    expect(stats.totalCount, greaterThanOrEqualTo(2));

    final future = ok(await orders.kioskStats('q9-t2', since: DateTime.now().add(const Duration(days: 1))));
    expect(future.totalCount, 0, reason: 'an order placed before the shift started is not counted');

    expect(err(await orders.kioskStats('q9-t4', since: since)), isA<PermissionDeniedException>());
  });

  testWidgets('customer: S24 reports a problem once per delivered order, and S23 saves and changes a review', (
    tester,
  ) async {
    final service = authAs('customer-1', 'Nguyễn Minh Quân');
    ok(await service.signInWithGoogle());
    final incidents = FirestoreIncidentRepository(db);
    final reviews = FirestoreReviewRepository(db);
    final delivered = (await orders.watchOrder(cashOrderId).firstWhere((o) => o != null))!;
    expect(delivered.status, OrderStatus.delivered);

    expect(
      err(await incidents.report(order: delivered, type: IncidentType.missingItem, description: '   ')),
      isA<ValidationException>(),
    );
    final incident = ok(
      await incidents.report(
        order: delivered,
        type: IncidentType.missingItem,
        description: 'Thiếu một ly trà',
        customerName: 'Quân N.',
      ),
    );
    expect(incident.orderId, cashOrderId);
    expect(incident.status, IncidentStatus.open);
    expect(
      err(await incidents.report(order: delivered, type: IncidentType.wrongItem, description: 'Báo lần hai')),
      isA<PermissionDeniedException>(),
      reason: 'one report for each order',
    );
    final seen = await incidents.watchOfOrder(customerUid, cashOrderId).firstWhere((i) => i != null);
    expect(seen!.description, 'Thiếu một ly trà');

    final item = delivered.items.first;
    final first = ok(
      await reviews.save(
        order: delivered,
        item: item,
        rating: 5,
        tags: const ['tasty'],
        authorName: 'Nguyễn Minh Quân',
      ),
    );
    expect(first.rating, 5);
    final data = (await db.doc('reviews/${cashOrderId}_${item.itemId}').get()).data()!;
    expect(data['rating'], 5);
    expect(data['dishId'], ReviewRepository.dishIdOf('q9-t2', item.itemId));
    expect(data['authorName'], isNot('Nguyễn Minh Quân'), reason: 'only a shortened public name is stored');
    ok(await reviews.save(order: delivered, item: item, rating: 4, comment: 'Hơi nguội', tags: const ['tasty', 'hot']));
    final changed = await reviews.watchOfOrder(customerUid, cashOrderId).firstWhere((l) => l.single.rating == 4);
    expect(changed.single.comment, 'Hơi nguội');
    expect(changed.single.tags, ['tasty', 'hot']);

    expect(err(await reviews.save(order: delivered, item: item, rating: 6)), isA<ValidationException>());
    expect(
      err(await reviews.save(order: delivered, item: item, rating: 3, tags: const ['unknown'])),
      isA<ValidationException>(),
    );
    final notDelivered = (await orders.watchOrder(voucherOrderId).firstWhere((o) => o != null))!;
    expect(notDelivered.status, isNot(OrderStatus.delivered));
    expect(
      err(await reviews.save(order: notDelivered, item: notDelivered.items.first, rating: 5)),
      isA<PermissionDeniedException>(),
    );
    // The rules let a customer report any order of their own; S12 only offers the button once it was received.
  });

  testWidgets('staff: K13 takes a report on, refunds it or rejects it with a reason; the customer sees the answer', (
    tester,
  ) async {
    final customer = authAs('customer-1', 'Nguyễn Minh Quân');
    ok(await customer.signInWithGoogle());
    final incidents = FirestoreIncidentRepository(db);
    final second = (await orders.watchOrder(voucherOrderId).firstWhere((o) => o != null))!;
    ok(
      await incidents.report(
        order: second,
        type: IncidentType.quality,
        description: 'Món nguội',
        customerName: 'Quân N.',
      ),
    );
    final delivered = (await orders.watchOrder(cashOrderId).firstWhere((o) => o != null))!;

    final service = authAs('staff-1', 'Cô Hạnh');
    final staff = ok(await service.signInWithGoogle());
    expect(staff.role, UserRole.staff);
    final list = await incidents.watchKioskIncidents('q9-t2').firstWhere((l) => l.length >= 2);
    expect(list.map((i) => i.orderId), containsAll([cashOrderId, voucherOrderId]));
    expect(list.every((i) => i.status == IncidentStatus.open), isTrue);
    expect(list.first.createdAt.isAfter(DateTime(2020)), isTrue);

    final missing = list.firstWhere((i) => i.orderId == cashOrderId);
    ok(await incidents.take(missing, staffUid: staff.uid));
    final taken = await incidents
        .watchKioskIncidents('q9-t2')
        .firstWhere((l) => l.any((i) => i.orderId == cashOrderId && i.status == IncidentStatus.inProgress));
    expect(taken.firstWhere((i) => i.orderId == cashOrderId).status, IncidentStatus.inProgress);
    expect(
      taken.indexWhere((i) => i.status == IncidentStatus.open),
      lessThan(taken.indexWhere((i) => i.status == IncidentStatus.inProgress)),
      reason: 'new reports come before the ones being handled',
    );

    expect(
      err(await incidents.resolve(missing, resolution: IncidentResolution.refunded, staffUid: staff.uid, refundVnd: 0)),
      isA<ValidationException>(),
    );
    expect(
      err(
        await incidents.resolve(
          missing,
          resolution: IncidentResolution.refunded,
          staffUid: staff.uid,
          refundVnd: delivered.totalVnd + 1000,
        ),
      ),
      isA<PermissionDeniedException>(),
      reason: 'the rules refuse a refund above what the customer paid',
    );
    expect(
      err(await incidents.resolve(missing, resolution: IncidentResolution.rejected, staffUid: staff.uid, note: '  ')),
      isA<ValidationException>(),
    );
    ok(
      await incidents.resolve(
        missing,
        resolution: IncidentResolution.refunded,
        staffUid: staff.uid,
        refundVnd: delivered.totalVnd,
      ),
    );
    final other = list.firstWhere((i) => i.orderId == voucherOrderId);
    ok(
      await incidents.resolve(
        other,
        resolution: IncidentResolution.rejected,
        staffUid: staff.uid,
        note: 'Đã kiểm tra, món vừa ra',
      ),
    );
    final done = await incidents
        .watchKioskIncidents('q9-t2')
        .firstWhere((l) => l.where((i) => i.status == IncidentStatus.resolved).length >= 2);
    final refunded = done.firstWhere((i) => i.orderId == cashOrderId);
    expect(
      (refunded.resolution, refunded.refundVnd, refunded.handledBy),
      (IncidentResolution.refunded, delivered.totalVnd, staff.uid),
    );
    expect(refunded.resolvedAt, isNotNull);
    expect(done.firstWhere((i) => i.orderId == voucherOrderId).resolutionNote, 'Đã kiểm tra, món vừa ra');
    expect(
      err(await incidents.take(refunded, staffUid: staff.uid)),
      isA<PermissionDeniedException>(),
      reason: 'an answered report is not taken on again',
    );
    // [CR-03] `missing` is the copy another staff member held before the answer: the check reads the document.
    expect(
      err(
        await incidents.resolve(
          missing,
          resolution: IncidentResolution.rejected,
          staffUid: staff.uid,
          note: 'Trả lời lần hai',
        ),
      ),
      isA<PermissionDeniedException>(),
      reason: 'a stale copy cannot answer a report twice',
    );
    expect(
      (await incidents.watchKioskIncidents('q9-t2').first).firstWhere((i) => i.orderId == cashOrderId).resolution,
      IncidentResolution.refunded,
    );

    // The customer reads the answer on S24.
    ok(await customer.signInWithGoogle());
    final seen = await incidents
        .watchOfOrder(customerUid, cashOrderId)
        .firstWhere((i) => i?.status == IncidentStatus.resolved);
    expect((seen!.resolution, seen.refundVnd), (IncidentResolution.refunded, delivered.totalVnd));
  });

  testWidgets('customer: S13 favorites, S19 notifications and S18 switches pass the rules and stay per customer', (
    tester,
  ) async {
    final service = authAs('customer-1', 'Nguyễn Minh Quân');
    final me = ok(await service.signInWithGoogle());
    final favorites = FirestoreFavoriteRepository(db);
    final inbox = FirestoreNotificationRepository(db);
    final tacos = ok(await menu.getItem('q9-t2-tacos-bo'));
    final tea = ok(await menu.getItem('q9-t2-tra-dao'));

    ok(await favorites.add(me.uid, tacos));
    ok(await favorites.add(me.uid, tea));
    final stored = await favorites.watch(me.uid).firstWhere((l) => l.length == 2);
    expect(stored.map((f) => f.dishId).toSet(), {'tacos-bo', 'tra-dao'});
    expect(stored.first.createdAt, isNotNull);
    final tacosBefore = stored.firstWhere((f) => f.dishId == 'tacos-bo').createdAt;
    ok(await favorites.add(me.uid, tacos));
    final again = await favorites.watch(me.uid).first;
    expect(
      again.firstWhere((f) => f.dishId == 'tacos-bo').createdAt,
      tacosBefore,
      reason: 'a second heart changes nothing',
    );
    ok(await favorites.remove(me.uid, 'tra-dao'));
    expect((await favorites.watch(me.uid).firstWhere((l) => l.length == 1)).single.dishId, 'tacos-bo');
    ok(await favorites.remove(me.uid, 'not-there'));
    expect(err(await favorites.add('', tacos)), isA<PermissionDeniedException>());
    expect(
      err(await favorites.add('someone-else', tacos)),
      isA<PermissionDeniedException>(),
      reason: 'another customer\'s favorites are not writable',
    );

    final ready = AppNotification(
      id: AppNotification.idForOrder(cashOrderId, OrderStatus.ready),
      title: 'Đơn đã sẵn sàng',
      body: 'Nhận món',
      receivedAt: DateTime.now(),
      orderId: cashOrderId,
    );
    ok(await inbox.save(me.uid, ready));
    ok(await inbox.save(me.uid, ready));
    ok(
      await inbox.save(
        me.uid,
        AppNotification(id: 'ann_1', title: 'Combo giờ vàng', body: '', receivedAt: DateTime.now()),
      ),
    );
    // The inbox may hold notifications of earlier tests, so only the two of this test are looked at.
    List<AppNotification> mine(List<AppNotification> l) => l.where((n) => n.id == ready.id || n.id == 'ann_1').toList();
    final all = mine(await inbox.watch(me.uid).firstWhere((l) => mine(l).length == 2));
    expect(all.every((n) => !n.read), isTrue);
    expect(all.firstWhere((n) => n.id == ready.id).orderId, cashOrderId);
    ok(await inbox.markRead(me.uid, ready.id));
    final one = mine(await inbox.watch(me.uid).firstWhere((l) => mine(l).any((n) => n.read)));
    expect(one.where((n) => n.read).map((n) => n.id), [ready.id]);
    ok(await inbox.markAllRead(me.uid));
    final allRead = await inbox.watch(me.uid).firstWhere((l) => l.every((n) => n.read));
    expect(mine(allRead), hasLength(2));
    ok(await inbox.markAllRead(me.uid));
    expect(err(await inbox.save('someone-else', ready)), isA<PermissionDeniedException>());

    expect(await inbox.watchPrefs(me.uid).first, NotificationPrefs.defaults);
    const changed = NotificationPrefs(orderReady: false, breakReminder: true, promo: true, orderUpdates: true);
    ok(await inbox.setPrefs(me.uid, changed));
    expect(await inbox.watchPrefs(me.uid).firstWhere((p) => p == changed), changed);
    expect((await db.doc('users/${me.uid}').get()).data()!['role'], 'user', reason: 'the other fields are left alone');
  });
}
