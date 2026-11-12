import 'package:breakbite_core/domain/cart_repricing.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _tacos = MenuItem(id: 'k-tacos', name: 'Tacos', priceVnd: 39000, category: ItemCategory.food, prepMinutes: 4);
const _tea = MenuItem(id: 'k-tea', name: 'Trà', priceVnd: 20000, category: ItemCategory.drink, prepMinutes: 2);

void main() {
  test('an unchanged cart has no changes and keeps every line', () {
    const lines = [CartItem(itemId: 'k-tacos', name: 'Tacos', priceVnd: 39000, quantity: 2)];
    final result = repriceCart(lines, {'k-tacos': _tacos});
    expect(result.hasChanges, isFalse);
    expect(result.subtotalVnd, 78000);
  });

  test('a new price replaces the old one and is reported', () {
    const lines = [CartItem(itemId: 'k-tacos', name: 'Tacos', priceVnd: 35000, quantity: 2, note: 'Ít cay')];
    final result = repriceCart(lines, {'k-tacos': _tacos});
    expect(result.changes.single, isA<PriceChanged>().having((c) => c.newPriceVnd, 'newPriceVnd', 39000));
    expect(result.lines.single.priceVnd, 39000);
    expect(result.lines.single.note, 'Ít cay');
    expect(result.subtotalVnd, 78000);
  });

  test('sold-out and no-longer-sold items leave the cart and are reported', () {
    const lines = [
      CartItem(itemId: 'k-tacos', name: 'Tacos', priceVnd: 39000),
      CartItem(itemId: 'k-tea', name: 'Trà', priceVnd: 20000),
      CartItem(itemId: 'k-gone', name: 'Cũ', priceVnd: 10000),
    ];
    final result = repriceCart(lines, {'k-tacos': _tacos, 'k-tea': _tea.copyWith(soldOut: true)});
    expect(result.lines.map((l) => l.itemId), ['k-tacos']);
    expect(result.changes.map((c) => c.runtimeType), [NowSoldOut, NoLongerSold]);
  });
}
