import 'package:flutter_test/flutter_test.dart';
import 'package:breakbite/domain/models/models.dart';

void main() {
  final now = DateTime(2026, 10, 29, 9);

  group('Voucher.discountFor', () {
    final fixed = Voucher(code: 'BBSTUDENT', discountVnd: 10000, expiresAt: DateTime(2100), minOrderVnd: 40000);

    test('đủ điều kiện thì giảm đúng số tiền cố định', () {
      expect(fixed.discountFor(50000, now), 10000);
    });
    test('chưa đạt đơn tối thiểu thì không giảm', () {
      expect(fixed.discountFor(39000, now), 0);
    });
    test('hết hạn hoặc bị tắt thì không giảm', () {
      final expired = Voucher(code: 'BB20', discountVnd: 20000, expiresAt: DateTime(2020), minOrderVnd: 0);
      final off = Voucher(code: 'OFF', discountVnd: 5000, expiresAt: DateTime(2100), minOrderVnd: 0, active: false);
      expect(expired.discountFor(50000, now), 0);
      expect(off.discountFor(50000, now), 0);
    });
    test('giảm theo phần trăm có trần', () {
      final pct = Voucher(code: 'P', discountVnd: 0, expiresAt: DateTime(2100), minOrderVnd: 0, percent: 20, maxDiscountVnd: 15000);
      expect(pct.discountFor(50000, now), 10000);
      expect(pct.discountFor(200000, now), 15000);
    });
    test('mức giảm không vượt tạm tính', () {
      final big = Voucher(code: 'BIG', discountVnd: 50000, expiresAt: DateTime(2100), minOrderVnd: 0);
      expect(big.discountFor(30000, now), 30000);
    });
  });

  group('PickupSlot', () {
    test('còn chỗ và hết chỗ', () {
      final open = PickupSlot(id: 's1', startAt: now, endAt: now.add(const Duration(minutes: 15)), capacity: 10, booked: 9);
      final full = PickupSlot(id: 's2', startAt: now, endAt: now.add(const Duration(minutes: 15)), capacity: 10, booked: 10);
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

    test('chỉ sửa được khi còn pending', () {
      expect(order(OrderStatus.pending).customerCanEdit, isTrue);
      expect(order(OrderStatus.preparing).customerCanEdit, isFalse);
    });
    test('mã QR gồm id đơn và mã nhận', () {
      expect(order(OrderStatus.ready).qrPayload, 'bb:abc123:482915');
    });
  });

  test('Review dùng id {orderId}_{itemId}', () {
    final r = Review(orderId: 'o6', itemId: 'm1', kioskId: 'q9-t2', uid: 'u1', rating: 5, createdAt: now);
    expect(r.id, 'o6_m1');
  });
}
