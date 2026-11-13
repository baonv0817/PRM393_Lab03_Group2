import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/domain/cart_repricing.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = OptionGroup(
  id: 'size',
  name: 'Size',
  required: true,
  choices: [
    OptionChoice(id: 's', name: 'Size S'),
    OptionChoice(id: 'm', name: 'Size M', extraVnd: 5000),
    OptionChoice(id: 'l', name: 'Size L', extraVnd: 10000),
  ],
);
const _topping = OptionGroup(
  id: 'topping',
  name: 'Topping',
  maxChoices: 2,
  choices: [
    OptionChoice(id: 'tc', name: 'Trân châu', extraVnd: 5000),
    OptionChoice(id: 'thach', name: 'Thạch', extraVnd: 3000),
    OptionChoice(id: 'pudding', name: 'Pudding', extraVnd: 7000),
  ],
);
const _tea = MenuItem(
  id: 'k-tea',
  kioskId: 'k',
  dishId: 'tea',
  name: 'Trà sữa',
  priceVnd: 25000,
  category: ItemCategory.drink,
  prepMinutes: 3,
  optionGroups: [_size, _topping],
);

MenuItem _teaWith({int price = 25000, List<OptionGroup> groups = const [_size, _topping]}) => MenuItem(
  id: _tea.id,
  kioskId: 'k',
  dishId: 'tea',
  name: _tea.name,
  priceVnd: price,
  category: _tea.category,
  prepMinutes: 3,
  optionGroups: groups,
);

void main() {
  group('OptionGroup', () {
    test('a required group needs a choice, and no group takes more than its maximum', () {
      expect(_size.problemWith({}), 'Chọn Size');
      expect(_size.problemWith({'m'}), isNull);
      expect(_topping.problemWith({}), isNull, reason: 'toppings are optional');
      expect(_topping.problemWith({'tc', 'thach'}), isNull);
      expect(_topping.problemWith({'tc', 'thach', 'pudding'}), 'Topping: chọn tối đa 2');
    });

    test('says what staff typed wrong: a name, a choice, a price, duplicates', () {
      OptionGroup group({String name = 'Size', List<OptionChoice>? choices, int max = 1}) => OptionGroup(
        id: 'g',
        name: name,
        maxChoices: max,
        choices: choices ?? const [OptionChoice(id: 'a', name: 'A'), OptionChoice(id: 'b', name: 'B')],
      );
      expect(group().problem, isNull);
      expect(group(name: ' ').problem, contains('cần có tên'));
      expect(group(choices: const []).problem, contains('ít nhất một lựa chọn'));
      expect(
        group(
          choices: const [OptionChoice(id: 'a', name: '')],
        ).problem,
        contains('chưa có tên'),
      );
      expect(
        group(
          choices: const [OptionChoice(id: 'a', name: 'A', extraVnd: -1)],
        ).problem,
        contains('không hợp lệ'),
      );
      expect(
        group(
          choices: const [
            OptionChoice(id: 'a', name: 'A'),
            OptionChoice(id: 'b', name: ' a '),
          ],
        ).problem,
        contains('trùng tên'),
      );
      expect(group(max: 3).problem, contains('tối đa phải từ 1 đến 2'));
    });

    test('an item takes at most five groups, with different names', () {
      expect(optionGroupsProblem([_size, _topping]), isNull);
      expect(optionGroupsProblem([_size, _size]), isNotNull);
      final six = [
        for (var i = 0; i < 6; i++)
          OptionGroup(
            id: 'g$i',
            name: 'Nhóm $i',
            choices: const [OptionChoice(id: 'a', name: 'A')],
          ),
      ];
      expect(optionGroupsProblem(six), contains('tối đa 5'));
    });
  });

  group('MenuItem with options', () {
    test('prices one portion with the extras of what was picked', () {
      expect(_tea.priceWith({}), 25000);
      expect(
        _tea.priceWith({
          'size': {'l'},
          'topping': {'tc', 'thach'},
        }),
        25000 + 10000 + 5000 + 3000,
      );
    });

    test('lists the choices in the order of the groups and ignores ones that are not offered', () {
      final choices = _tea.choicesFor({
        'topping': {'thach', 'nope'},
        'size': {'m'},
        'ghost': {'x'},
      });
      expect(choices.map((c) => c.name), ['Size M', 'Thạch']);
      expect(choices.first.groupName, 'Size');
    });

    test('is not ready to add until the required groups are answered', () {
      expect(_tea.optionsProblem({}), 'Chọn Size');
      expect(
        _tea.optionsProblem({
          'size': {'s'},
        }),
        isNull,
      );
    });

    test('keeps its options through the copies staff make (sold out, archived, price)', () {
      expect(_tea.withSoldOut(true).optionGroups, hasLength(2));
      expect(_tea.withArchived(true).optionGroups, hasLength(2));
      expect(_tea.copyWith(priceVnd: 1).optionGroups, hasLength(2));
      expect(_tea.hasOptions, isTrue);
    });
  });

  group('CartItem lines', () {
    CartItem line(List<SelectedChoice> options, {int quantity = 1}) => CartItem(
      itemId: 'k-tea',
      name: 'Trà sữa',
      priceVnd: 25000 + options.fold(0, (a, o) => a + o.extraVnd),
      quantity: quantity,
      options: options,
    );
    final m = _tea.choicesFor({
      'size': {'m'},
    });
    final mThach = _tea.choicesFor({
      'size': {'m'},
      'topping': {'thach'},
    });

    test('a dish without options keeps its dish id as the key', () {
      expect(const CartItem(itemId: 'm1', name: 'Tacos', priceVnd: 39000).lineKey, 'm1');
    });

    test('the same dish with other choices is another line, the same choices are one line', () {
      expect(line(m).lineKey, isNot(line(mThach).lineKey));
      expect(line(m).lineKey, line(m, quantity: 3).lineKey);
      final reversed = _tea.choicesFor({
        'topping': {'thach', 'tc'},
      });
      final forwards = _tea.choicesFor({
        'topping': {'tc', 'thach'},
      });
      expect(line(reversed).lineKey, line(forwards).lineKey);
    });

    test('reads on one line, and the key is safe to use as a test id', () {
      expect(line(mThach).optionsSummary, 'Size M · Thạch');
      expect(line(mThach).displayName, 'Trà sữa (Size M · Thạch)');
      expect(line(const []).displayName, 'Trà sữa');
      expect(RegExp(r'^[A-Za-z0-9-]+$').hasMatch(line(mThach).lineSlug), isTrue);
      expect(line(mThach).lineTotalVnd, 33000, reason: 'dish 25.000 + M 5.000 + thạch 3.000');
      expect(line(mThach).extrasVnd, 8000);
    });
  });

  group('storage', () {
    test('option groups survive a write and a read', () {
      final data = menuItemToData(_tea, dishId: 'tea');
      final back = menuItemFromData('k-tea', data);
      expect(back.optionGroups, hasLength(2));
      expect(back.optionGroups.first.required, isTrue);
      expect(back.optionGroups.last.maxChoices, 2);
      expect(back.optionGroups.last.choices.last.extraVnd, 7000);
    });

    test('an item without options writes an empty list, so editing it can clear them', () {
      final plain = _teaWith(groups: const []);
      expect(menuItemToData(plain, dishId: 'tea')['optionGroups'], isEmpty);
      expect(menuItemFromData('k-x', {'name': 'X', 'optionGroups': 'garbage'}).optionGroups, isEmpty);
    });

    test('a cart line carries its options, and a line without options stays as it was', () {
      final line = CartItem(
        itemId: 'k-tea',
        name: 'Trà sữa',
        priceVnd: 30000,
        options: _tea.choicesFor({
          'size': {'m'},
        }),
      );
      final back = cartItemFromData(cartItemToData(line));
      expect(back.options.single.name, 'Size M');
      expect(back.options.single.extraVnd, 5000);
      expect(back.lineKey, line.lineKey);
      expect(
        cartItemToData(const CartItem(itemId: 'm1', name: 'Tacos', priceVnd: 39000)).containsKey('options'),
        isFalse,
      );
    });
  });

  group('repriceCart with options', () {
    CartItem pick(Map<String, Set<String>> picked) =>
        CartItem(itemId: 'k-tea', name: 'Trà sữa', priceVnd: _tea.priceWith(picked), options: _tea.choicesFor(picked));
    final large = {
      'size': {'l'},
    };

    test('a line at the price of today is kept as it is', () {
      final result = repriceCart([pick(large)], {'k-tea': _tea});
      expect(result.hasChanges, isFalse);
      expect(result.lines.single.priceVnd, 35000);
    });

    test('when the dish costs something else now, the line gets the new price and says so', () {
      final result = repriceCart([pick(large)], {'k-tea': _teaWith(price: 27000)});
      expect(result.changes.single, isA<PriceChanged>());
      expect(result.lines.single.priceVnd, 37000);
      expect(result.lines.single.options.single.name, 'Size L');
    });

    test('a choice staff took off the item is reported, and the line is not kept', () {
      final withoutL = _teaWith(
        groups: [OptionGroup(id: 'size', name: 'Size', required: true, choices: _size.choices.take(2).toList())],
      );
      final result = repriceCart([pick(large)], {'k-tea': withoutL});
      expect(result.changes.single, isA<OptionUnavailable>());
      expect((result.changes.single as OptionUnavailable).optionName, 'Size L');
      expect(result.lines, isEmpty);
    });
  });
}
