import 'package:breakbite/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 29, 9);

  group('Voucher.discountFor', () {
    final fixed = Voucher(code: 'BBSTUDENT', discountVnd: 10000, expiresAt: DateTime(2100), minOrderVnd: 40000);

    test('eligible order gets exactly the fixed discount', () {
      expect(fixed.discountFor(50000, now), 10000);
    });
    test('no discount below the minimum order', () {
      expect(fixed.discountFor(39000, now), 0);
    });
    test('no discount when expired or disabled', () {
      final expired = Voucher(code: 'BB20', discountVnd: 20000, expiresAt: DateTime(2020), minOrderVnd: 0);
      final off = Voucher(code: 'OFF', discountVnd: 5000, expiresAt: DateTime(2100), minOrderVnd: 0, active: false);
      expect(expired.discountFor(50000, now), 0);
      expect(off.discountFor(50000, now), 0);
    });
    test('percentage discount is capped', () {
      final pct = Voucher(
        code: 'P',
        discountVnd: 0,
        expiresAt: DateTime(2100),
        minOrderVnd: 0,
        percent: 20,
        maxDiscountVnd: 15000,
      );
      expect(pct.discountFor(50000, now), 10000);
      expect(pct.discountFor(200000, now), 15000);
    });
    test('discount never exceeds the subtotal', () {
      final big = Voucher(code: 'BIG', discountVnd: 50000, expiresAt: DateTime(2100), minOrderVnd: 0);
      expect(big.discountFor(30000, now), 30000);
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

  test('Review uses id {orderId}_{itemId}', () {
    final r = Review(orderId: 'o6', itemId: 'm1', kioskId: 'q9-t2', uid: 'u1', rating: 5, createdAt: now);
    expect(r.id, 'o6_m1');
  });
}
