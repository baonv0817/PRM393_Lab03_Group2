import 'package:breakbite/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final created = DateTime.utc(2026, 11, 2, 2);

  test('a menu item reads every field and writes back the shape the rules check', () {
    final item = menuItemFromData('q9-t2-tacos-bo', {
      'kioskId': 'q9-t2',
      'dishId': 'tacos-bo',
      'name': 'Combo Tacos Bò Phô Mai',
      'priceVnd': 39000,
      'category': 'food',
      'prepMinutes': 4,
      'soldOut': true,
      'imageUrl': 'assets/images/menu/tacos-bo.jpg',
    });
    expect(item.category, ItemCategory.food);
    expect(item.soldOut, isTrue);

    final data = menuItemToData(item, dishId: item.dishId);
    expect(data['searchName'], 'combo tacos bo pho mai');
    expect(data['category'], 'food');
    expect(data.keys, containsAll(['kioskId', 'dishId', 'name', 'priceVnd', 'prepMinutes', 'soldOut']));
  });

  test('an unknown category reads as other instead of failing', () {
    expect(menuItemFromData('x', {'category': 'Tacos'}).category, ItemCategory.other);
  });

  group('vouchers', () {
    Map<String, dynamic> base(Map<String, dynamic> discount) => {
      'title': 't',
      'discount': discount,
      'minOrderVnd': 30000,
      'expiresAt': Timestamp.fromDate(DateTime.utc(2100)),
      'active': true,
      'activeFrom': '10:15',
      'activeTo': '10:30',
    };

    test('fixed and percent shapes become the matching discount', () {
      final fixed = voucherFromData('BBSTUDENT', base({'type': 'fixed', 'amountVnd': 10000}))!;
      final percent = voucherFromData('GIOVANG', base({'type': 'percent', 'percent': 15, 'maxVnd': 15000}))!;
      expect(fixed.discount, isA<FixedDiscount>().having((d) => d.amountVnd, 'amountVnd', 10000));
      expect(percent.discount, isA<PercentDiscount>().having((d) => d.maxVnd, 'maxVnd', 15000));
      expect(percent.activeFrom, '10:15');
    });

    test('a malformed voucher reads as null, so the app never applies a wrong discount', () {
      expect(voucherFromData('X', base({'type': 'percent', 'percent': 15})), isNull);
      expect(voucherFromData('X', base({'type': 'fixed', 'amountVnd': 0})), isNull);
      expect(
        voucherFromData('X', {
          'discount': {'type': 'fixed', 'amountVnd': 1},
        }),
        isNull,
      );
    });
  });

  test('a cart round-trips; empty optional fields are null so the repository can delete them', () {
    final cart = Cart(
      kioskId: 'q9-t2',
      items: const [CartItem(itemId: 'q9-t2-tacos-bo', name: 'Tacos', priceVnd: 39000, quantity: 2, note: 'Ít cay')],
      pickupSlotId: '20261102-1015',
      pickupAt: created,
    );
    final data = cartToData(cart);
    expect(data['voucherCode'], isNull);
    expect(data['pickupAt'], isA<Timestamp>());
    final back = cartFromData({for (final e in data.entries) e.key: e.value});
    expect(back.items.single.note, 'Ít cay');
    expect(back.items.single.quantity, 2);
    expect(back.pickupAt!.isAtSameMomentAs(created), isTrue);
    expect(cartFromData(null).isEmpty, isTrue);
  });

  test('an order reads its lifecycle fields; a pending server timestamp falls back to now', () {
    final order = orderFromData('abcdefghij', {
      'uid': 'u1',
      'kioskId': 'q9-t2',
      'items': [
        {'itemId': 'q9-t2-tacos-bo', 'name': 'Tacos', 'priceVnd': 39000, 'quantity': 1, 'note': ''},
      ],
      'subtotalVnd': 39000,
      'discountVnd': 5850,
      'totalVnd': 33150,
      'voucherCode': 'GIOVANG',
      'paymentMethod': 'cash',
      'paymentStatus': 'unpaid',
      'status': 'preparing',
      'pickupCode': '482915',
      'createdAt': null,
      'acceptedAt': Timestamp.fromDate(created),
      'readyBy': Timestamp.fromDate(created.add(const Duration(minutes: 5))),
      'cancelledBy': 'staff',
    }, now: created);
    expect(order.orderCode, 'ABCDEF');
    expect(order.status, OrderStatus.preparing);
    expect(order.paymentStatus, PaymentStatus.unpaid);
    expect(order.createdAt, created);
    expect(order.acceptedAt!.isAtSameMomentAs(created), isTrue);
    expect(order.cancelledBy, CancelledBy.staff);
    expect(order.qrPayload, 'bb:abcdefghij:482915');
  });

  test('a user profile falls back to the Google account when the document is missing', () {
    final user = appUserFromData('u1', null, fallbackName: 'Minh Quân', email: 'q@example.com');
    expect(user.role, UserRole.user);
    expect(user.displayName, 'Minh Quân');
    final staff = appUserFromData('u2', {'role': 'staff', 'kioskId': 'q9-t2'}, fallbackName: 'x');
    expect(staff.isStaff, isTrue);
    expect(staff.kioskId, 'q9-t2');
  });

  test('a kiosk and a pickup slot read their fields', () {
    final kiosk = kioskFromData('q9-t2', {
      'name': 'Kiosk Q9 · Tầng 2',
      'open': true,
      'waitMinutes': 6,
      'pausedUntil': Timestamp.fromDate(created),
    });
    expect(kiosk.pausedUntil!.isAtSameMomentAs(created), isTrue);
    final slot = pickupSlotFromData('20261102-0845', {
      'startAt': Timestamp.fromDate(created),
      'endAt': Timestamp.fromDate(created.add(const Duration(minutes: 15))),
      'capacity': 15,
      'booked': 15,
    });
    expect(slot.isFull, isTrue);
  });

  test('a report reads its metadata; a pending server time falls back to now', () {
    final now = DateTime.utc(2026, 11, 2, 3);
    final report = reportFromData('r1', {
      'uid': 'u1',
      'fileName': 'breakbite-don-hang.pdf',
      'url': 'https://res.cloudinary.com/demo/x.pdf',
      'publicId': 'breakbite/reports/u1/x',
      'sizeKb': 9,
      'createdAt': Timestamp.fromDate(created),
    }, now: now);
    expect(report.uid, 'u1');
    expect(report.sizeKb, 9);
    expect(report.orderId, isNull);
    expect(report.createdAt.isAtSameMomentAs(created), isTrue);
    expect(reportFromData('r2', {'uid': 'u1'}, now: now).createdAt, now);
  });

  test('a user profile reads its optional fields; an unknown payment method is ignored', () {
    final profile = userProfileFromData('u1', {
      'displayName': 'Quân',
      'email': 'quan@fpt.edu.vn',
      'studentId': 'SE183398',
      'phone': '0912345678',
      'defaultKioskId': 'q9-t4',
      'defaultPaymentMethod': 'cash',
    });
    expect(profile.studentId, 'SE183398');
    expect(profile.defaultKioskId, 'q9-t4');
    expect(profile.defaultPaymentMethod, PaymentMethod.cash);
    expect(userProfileFromData('u1', {'defaultPaymentMethod': 'bitcoin'}).defaultPaymentMethod, isNull);
    expect(userProfileFromData('u1', null).displayName, '');
    expect(appUserFromData('u1', {'defaultKioskId': 'q9-t4'}, fallbackName: 'Q').defaultKioskId, 'q9-t4');
  });
}
