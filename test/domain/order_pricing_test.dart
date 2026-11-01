import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/domain/order_pricing.dart';
import 'package:breakbite/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 2, 3, 20);
  const items = [
    CartItem(itemId: 'a', name: 'Tacos', priceVnd: 39000),
    CartItem(itemId: 'b', name: 'Trà', priceVnd: 20000, quantity: 2),
  ];

  test('without a voucher the total is the subtotal', () {
    final pricing = priceOrder(items, now: now);
    expect(pricing.subtotalVnd, 79000);
    expect(pricing.discountVnd, 0);
    expect(pricing.totalVnd, 79000);
  });

  test('a voucher takes off exactly its discount', () {
    final voucher = Voucher(code: 'BBSTUDENT', discount: const FixedDiscount(10000), expiresAt: DateTime(2100));
    final pricing = priceOrder(items, voucher: voucher, now: now);
    expect(pricing.discountVnd, 10000);
    expect(pricing.totalVnd, 69000);
  });

  group('Voucher.problemFor explains why a voucher does not apply', () {
    Voucher voucher({bool active = true, DateTime? startsAt, DateTime? expiresAt, int minOrderVnd = 0}) => Voucher(
      code: 'GIOVANG',
      discount: const PercentDiscount(percent: 15, maxVnd: 15000),
      expiresAt: expiresAt ?? DateTime(2100),
      startsAt: startsAt,
      minOrderVnd: minOrderVnd,
      activeFrom: '10:15',
      activeTo: '10:30',
      active: active,
    );

    test('each reason is reported, in a fixed order', () {
      expect(voucher().problemFor(40000, now), isNull);
      expect(voucher(active: false).problemFor(40000, now), VoucherProblem.inactive);
      expect(voucher(startsAt: DateTime(2099)).problemFor(40000, now), VoucherProblem.notStarted);
      expect(voucher(expiresAt: DateTime(2020)).problemFor(40000, now), VoucherProblem.expired);
      expect(voucher().problemFor(40000, DateTime.utc(2026, 11, 2, 4)), VoucherProblem.outsideActiveHours);
      expect(voucher(minOrderVnd: 50000).problemFor(40000, now), VoucherProblem.belowMinimum);
    });

    test('every reason has a message the customer can read', () {
      final v = voucher(minOrderVnd: 50000);
      expect(voucherProblemMessage(v, VoucherProblem.belowMinimum), 'Đơn tối thiểu 50.000đ để dùng mã GIOVANG.');
      expect(voucherProblemMessage(v, VoucherProblem.outsideActiveHours), contains('10:15 đến 10:30'));
      for (final problem in VoucherProblem.values) {
        expect(voucherProblemMessage(v, problem), contains('GIOVANG'));
      }
    });
  });

  test('a kiosk accepts orders only when open and not paused', () {
    final at = DateTime(2026, 11, 2, 10);
    expect(const Kiosk(id: 'k', name: 'K', open: true, waitMinutes: 5).acceptsOrders(at), isTrue);
    expect(const Kiosk(id: 'k', name: 'K', open: false, waitMinutes: 5).acceptsOrders(at), isFalse);
    final paused = Kiosk(
      id: 'k',
      name: 'K',
      open: true,
      waitMinutes: 5,
      pausedUntil: at.add(const Duration(minutes: 15)),
    );
    expect(paused.acceptsOrders(at), isFalse);
    expect(paused.acceptsOrders(at.add(const Duration(minutes: 16))), isTrue);
  });

  test('a cart counts portions and its subtotal', () {
    const cart = Cart(kioskId: 'q9-t2', items: items);
    expect(cart.itemCount, 3);
    expect(cart.subtotalVnd, 79000);
    expect(Cart.empty.isEmpty, isTrue);
  });
}
