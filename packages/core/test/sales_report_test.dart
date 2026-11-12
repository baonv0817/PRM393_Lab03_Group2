import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Order _order(
  String id, {
  OrderStatus status = OrderStatus.delivered,
  String kiosk = 'q9-t2',
  int total = 40000,
  DateTime? at,
  int? prep,
  List<CartItem>? items,
}) => Order(
  id: id,
  uid: 'u',
  kioskId: kiosk,
  kioskName: kiosk == 'q9-t2' ? 'Kiosk Q9 · Tầng 2' : 'Kiosk Q9 · Tầng 4',
  items: items ?? const [CartItem(itemId: 'm1', name: 'Combo', priceVnd: 40000)],
  totalVnd: total,
  paymentMethod: PaymentMethod.momo,
  status: status,
  createdAt: at ?? DateTime.utc(2026, 11, 11, 5),
  prepSeconds: prep,
);

void main() {
  group('SalesReport', () {
    test('counts every state, and takes revenue and dishes from the delivered orders only', () {
      final report = SalesReport.fromOrders([
        _order('a', total: 40000, prep: 240),
        _order(
          'b',
          total: 60000,
          prep: 360,
          items: const [CartItem(itemId: 'm2', name: 'Trà', priceVnd: 30000, quantity: 2)],
        ),
        _order('c', status: OrderStatus.cancelled, total: 99000),
        _order('d', status: OrderStatus.pending),
        _order('e', status: OrderStatus.preparing),
      ]);

      expect((report.orders, report.delivered, report.cancelled, report.active), (5, 2, 1, 2));
      expect(report.revenueVnd, 100000, reason: 'the cancelled 99.000 brings in nothing');
      expect(report.averagePrepSeconds, 300);
      expect(report.averageOrderVnd, 50000);
      expect(report.cancelRate, closeTo(0.2, 1e-9));
      expect(report.topDishes.map((d) => (d.name, d.quantity)), [('Trà', 2), ('Combo', 1)]);
    });

    test('has no average and no rate for nothing, and does not divide by zero', () {
      final report = SalesReport.fromOrders(const []);
      expect((report.orders, report.revenueVnd, report.averageOrderVnd, report.cancelRate), (0, 0, 0, 0));
      expect(report.averagePrepSeconds, isNull);
      expect(report.byDay, isEmpty);
      expect(report.bestDayRevenueVnd, 0);
    });

    test('groups by day on the Vietnam calendar: 20:00 UTC is already the next day there', () {
      final report = SalesReport.fromOrders([
        _order('a', at: DateTime.utc(2026, 11, 11, 3), total: 10000),
        _order('b', at: DateTime.utc(2026, 11, 11, 20), total: 30000),
        _order('c', at: DateTime.utc(2026, 11, 12, 1), total: 50000),
        _order('d', at: DateTime.utc(2026, 11, 12, 2), status: OrderStatus.cancelled, total: 70000),
      ]);
      expect(report.byDay.map((d) => (d.day, d.orders, d.revenueVnd)), [
        (DateTime.utc(2026, 11, 11), 1, 10000),
        (DateTime.utc(2026, 11, 12), 3, 80000),
      ]);
      expect(report.bestDayRevenueVnd, 80000);
    });

    test('adds up by kiosk, the one with more takings first, and ranks the dishes by portions then by name', () {
      final report = SalesReport.fromOrders([
        _order('a', kiosk: 'q9-t4', total: 90000),
        _order('b', total: 10000),
        _order('c', status: OrderStatus.cancelled),
        _order(
          'd',
          items: const [CartItem(itemId: 'm1', name: 'Bánh mì', priceVnd: 22000)],
        ),
        _order(
          'e',
          items: const [CartItem(itemId: 'm1', name: 'Bánh mì', priceVnd: 22000)],
        ),
        _order(
          'f',
          items: const [CartItem(itemId: 'm3', name: 'Cà phê', priceVnd: 18000, quantity: 2)],
        ),
      ]);
      expect(report.byKiosk.map((k) => k.kioskId), ['q9-t2', 'q9-t4']);
      final q9t2 = report.byKiosk.first;
      expect((q9t2.orders, q9t2.delivered, q9t2.cancelled), (5, 4, 1));
      expect(report.topDishes.first.name, 'Bánh mì', reason: 'two portions each, "Bánh mì" before "Cà phê" by name');
      expect(report.topDishes.map((d) => d.name), containsAll(['Bánh mì', 'Cà phê', 'Combo']));
    });

    test('keeps the ten best sellers and remembers that it did not read every order', () {
      final many = [
        for (var i = 0; i < 15; i++)
          _order(
            'o$i',
            items: [CartItem(itemId: 'm$i', name: 'Món $i', priceVnd: 1000, quantity: i + 1)],
          ),
      ];
      final report = SalesReport.fromOrders(many, truncated: true);
      expect(report.topDishes, hasLength(SalesReport.topDishCount));
      expect(report.topDishes.first.name, 'Món 14');
      expect(report.truncated, isTrue);
    });

    test('names a kiosk by its id when the order carries no name', () {
      final order = Order(
        id: 'x',
        uid: 'u',
        kioskId: 'nvh-t1',
        items: const [],
        totalVnd: 1,
        paymentMethod: PaymentMethod.cash,
        status: OrderStatus.pending,
        createdAt: DateTime.utc(2026, 11, 11),
      );
      expect(SalesReport.fromOrders([order]).byKiosk.single.kioskName, 'nvh-t1');
    });

    test('splits each day by kiosk and counts the orders that were not cancelled by hour on the Vietnam clock', () {
      final report = SalesReport.fromOrders([
        _order('a', at: DateTime.utc(2026, 11, 11, 3), total: 10000),
        _order('b', kiosk: 'q9-t4', at: DateTime.utc(2026, 11, 11, 3, 30), total: 30000),
        _order('c', at: DateTime.utc(2026, 11, 11, 3, 40), status: OrderStatus.cancelled, total: 70000),
        _order('d', at: DateTime.utc(2026, 11, 11, 10), status: OrderStatus.pending),
      ]);
      expect(report.byDay.single.revenueByKiosk, {'q9-t2': 10000, 'q9-t4': 30000});
      expect(report.byHour[10], 2, reason: '03:00 UTC is 10:00 in Vietnam; the cancelled order is not counted');
      expect(report.byHour[17], 1);
      expect(report.byHour.fold(0, (a, b) => a + b), 3);
    });
  });
}
