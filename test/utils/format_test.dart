import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 10, 14, 10, 22);

  test('formats money in VND with dot separators', () {
    expect(formatVnd(39000), '39.000đ');
    expect(formatVnd(0), '0đ');
  });

  test('formats time, day and month, date and both together', () {
    expect(formatTime(at), '10:22');
    expect(formatDayMonth(at), '14/10');
    expect(formatDate(at), '14/10/2026');
    expect(formatDateTime(at), '10:22 · 14/10/2026');
  });

  test('time left reads as minutes, under one minute, or past due', () {
    expect(formatTimeLeft(at.add(const Duration(minutes: 3, seconds: 20)), now: at), 'còn 3 phút');
    expect(formatTimeLeft(at.add(const Duration(seconds: 40)), now: at), 'còn dưới 1 phút');
    expect(formatTimeLeft(at.subtract(const Duration(minutes: 1)), now: at), 'đã quá giờ');
  });

  test('every order status has a label', () {
    expect(OrderStatus.values.map(orderStatusLabel), ['Đã nhận đơn', 'Đang làm', 'Sẵn sàng', 'Hoàn tất', 'Đã huỷ']);
  });

  group('order money', () {
    Order order({PaymentStatus payment = PaymentStatus.paid, OrderStatus status = OrderStatus.delivered}) => Order(
      id: 'a1',
      uid: 'u1',
      kioskId: 'q9-t2',
      items: const [
        CartItem(itemId: 'm1', name: 'Combo', priceVnd: 39000, quantity: 2),
        CartItem(itemId: 'm2', name: 'Trà đào', priceVnd: 25000),
      ],
      totalVnd: 93000,
      paymentMethod: PaymentMethod.momo,
      paymentStatus: payment,
      status: status,
      createdAt: at,
    );

    test('the items total adds every line before a voucher', () {
      expect(orderItemsTotalVnd(order()), 103000);
    });

    test('the payment label says where the money stands', () {
      expect(orderPaymentLabel(order()), 'Đã thanh toán');
      expect(orderPaymentLabel(order(status: OrderStatus.cancelled)), 'Được hoàn tiền');
      expect(
        orderPaymentLabel(order(payment: PaymentStatus.unpaid, status: OrderStatus.pending)),
        'Trả tại quầy khi nhận',
      );
      expect(orderPaymentLabel(order(payment: PaymentStatus.unpaid, status: OrderStatus.cancelled)), 'Chưa thanh toán');
    });
  });
}
