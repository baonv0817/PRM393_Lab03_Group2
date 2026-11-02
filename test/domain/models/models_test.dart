import 'package:breakbite/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 29, 2);

  group('Voucher.discountFor', () {
    final fixed = Voucher(
      code: 'BBSTUDENT',
      discount: const FixedDiscount(10000),
      expiresAt: DateTime(2100),
      minOrderVnd: 40000,
    );

    test('eligible order gets exactly the fixed discount', () {
      expect(fixed.discountFor(50000, now), 10000);
    });
    test('no discount below the minimum order', () {
      expect(fixed.discountFor(39000, now), 0);
    });
    test('no discount when expired, disabled or not started yet', () {
      final expired = Voucher(code: 'BB20', discount: const FixedDiscount(20000), expiresAt: DateTime(2020));
      final off = Voucher(code: 'OFF', discount: const FixedDiscount(5000), expiresAt: DateTime(2100), active: false);
      final later = Voucher(
        code: 'LATER',
        discount: const FixedDiscount(5000),
        startsAt: DateTime(2099),
        expiresAt: DateTime(2100),
      );
      expect(expired.discountFor(50000, now), 0);
      expect(off.discountFor(50000, now), 0);
      expect(later.discountFor(50000, now), 0);
    });
    test('a percentage is rounded down and capped, like the security rules', () {
      final pct = Voucher(
        code: 'GIOVANG',
        discount: const PercentDiscount(percent: 15, maxVnd: 15000),
        expiresAt: DateTime(2100),
      );
      expect(pct.discountFor(39000, now), 5850);
      expect(pct.discountFor(39001, now), 5850);
      expect(pct.discountFor(200000, now), 15000);
    });
    test('the discount never exceeds the subtotal', () {
      final big = Voucher(code: 'BIG', discount: const FixedDiscount(50000), expiresAt: DateTime(2100));
      expect(big.discountFor(30000, now), 30000);
    });
    test('a daily window (Vietnam time) limits when the voucher works', () {
      final golden = Voucher(
        code: 'GIOVANG',
        discount: const PercentDiscount(percent: 15, maxVnd: 15000),
        expiresAt: DateTime(2100),
        activeFrom: '10:15',
        activeTo: '10:30',
      );
      expect(golden.discountFor(40000, DateTime.utc(2026, 10, 29, 3, 20)), 6000);
      expect(golden.discountFor(40000, DateTime.utc(2026, 10, 29, 3, 30)), 0);
      expect(golden.discountFor(40000, DateTime.utc(2026, 10, 29, 3, 14)), 0);
    });
  });

  group('PickupSlot', () {
    test('has remaining capacity and is full', () {
      final open = PickupSlot(
        id: 's1',
        startAt: now,
        endAt: now.add(const Duration(minutes: 15)),
        capacity: 10,
        booked: 9,
      );
      final full = PickupSlot(
        id: 's2',
        startAt: now,
        endAt: now.add(const Duration(minutes: 15)),
        capacity: 10,
        booked: 10,
      );
      expect(open.remaining, 1);
      expect(open.isFull, isFalse);
      expect(full.isFull, isTrue);
    });
  });

  group('Order', () {
    Order order(OrderStatus status) => Order(
      id: 'abc123',
      uid: 'u1',
      items: const [CartItem(itemId: 'm1', name: 'Tacos', priceVnd: 39000)],
      totalVnd: 39000,
      paymentMethod: PaymentMethod.momo,
      status: status,
      kioskId: 'q9-t2',
      createdAt: now,
      pickupCode: '482915',
    );

    test('editable only while pending', () {
      expect(order(OrderStatus.pending).customerCanEdit, isTrue);
      expect(order(OrderStatus.preparing).customerCanEdit, isFalse);
    });
    test('QR payload contains the order id and pickup code', () {
      expect(order(OrderStatus.ready).qrPayload, 'bb:abc123:482915');
    });
  });

  group('Review', () {
    test('uses id {orderId}_{itemId}', () {
      final r = Review(orderId: 'o6', itemId: 'q9-t2-tacos-bo', kioskId: 'q9-t2', uid: 'u1', rating: 5, createdAt: now);
      expect(r.id, 'o6_q9-t2-tacos-bo');
    });
    test('public author name keeps the given name and the family initial only', () {
      expect(Review.publicAuthorName('Nguyễn Minh Quân'), 'Quân N.');
      expect(Review.publicAuthorName('  Đỗ   Hoàng Gia Bảo '), 'Bảo Đ.');
      expect(Review.publicAuthorName('Linh'), 'Linh');
      expect(Review.publicAuthorName(''), 'Khách');
    });
  });

  test('Incident id is the order id, so an order has at most one incident', () {
    final incident = Incident(
      orderId: 'o6',
      kioskId: 'q9-t2',
      uid: 'u1',
      type: IncidentType.missingItem,
      description: 'Thiếu trà',
      status: IncidentStatus.open,
      createdAt: now,
    );
    expect(incident.id, 'o6');
  });

  test('stored enum values are the Dart enum names (no snake_case mapping)', () {
    expect(IncidentType.missingItem.name, 'missingItem');
    expect(IncidentStatus.inProgress.name, 'inProgress');
    expect(ItemCategory.values.map((c) => c.name), ['food', 'drink', 'other']);
    expect(SoldOutReason.values.map((r) => r.name), ['outOfIngredients', 'machineBroken', 'other']);
  });

  group('MenuItem sold out', () {
    final back = DateTime(2026, 11, 2, 10, 30);
    const item = MenuItem(id: 'm1', name: 'Combo', priceVnd: 39000, category: ItemCategory.food, prepMinutes: 4);

    test('withSoldOut replaces the reason and the expected time, and drops both when available again', () {
      final sold = item.withSoldOut(true, reason: SoldOutReason.machineBroken, availableAgainAt: back);
      expect((sold.soldOut, sold.soldOutReason, sold.availableAgainAt), (true, SoldOutReason.machineBroken, back));

      final again = sold.withSoldOut(true, reason: SoldOutReason.other);
      expect((again.soldOutReason, again.availableAgainAt), (SoldOutReason.other, null));

      final available = sold.withSoldOut(false, reason: SoldOutReason.other, availableAgainAt: back);
      expect((available.soldOut, available.soldOutReason, available.availableAgainAt), (false, null, null));
    });

    test('copyWith keeps the reason and time while sold out and drops them when switched back', () {
      final sold = item.withSoldOut(true, reason: SoldOutReason.outOfIngredients, availableAgainAt: back);
      expect(sold.copyWith(priceVnd: 40000).soldOutReason, SoldOutReason.outOfIngredients);
      expect(sold.copyWith(soldOut: false).soldOutReason, isNull);
      expect(sold.copyWith(soldOut: false).availableAgainAt, isNull);
    });
  });

  test('notification ids are deterministic so the same event is never stored twice', () {
    expect(AppNotification.idForOrder('o6', OrderStatus.ready), 'o6_ready');
    expect(AppNotification.idForAnnouncement('a1'), 'ann_a1');
  });
}
