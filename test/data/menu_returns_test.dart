import 'dart:async';

import 'package:breakbite/data/repositories/menu_returns.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

final _noon = DateTime(2026, 11, 11, 12);

MenuItem _item(String id, {bool soldOut = false, DateTime? backAt}) => MenuItem(
  id: id,
  name: id,
  priceVnd: 20000,
  category: ItemCategory.food,
  prepMinutes: 3,
  kioskId: 'q9-t2',
  soldOut: soldOut,
  availableAgainAt: backAt,
  soldOutReason: soldOut ? SoldOutReason.outOfIngredients : null,
);

void main() {
  group('MenuItem.availableAt', () {
    test('an item sold out until a time that has passed is on sale again, the reason and time dropped', () {
      final item = _item('a', soldOut: true, backAt: _noon.subtract(const Duration(minutes: 1)));
      final back = item.availableAt(_noon);
      expect((back.soldOut, back.availableAgainAt, back.soldOutReason), (false, null, null));
      expect(item.availableAt(_noon.subtract(const Duration(minutes: 2))).soldOut, isTrue, reason: 'not due yet');
    });

    test('staff left no time, the item is on sale, or the time is exactly now', () {
      final noTime = _item('a', soldOut: true);
      expect(noTime.availableAt(_noon), same(noTime), reason: 'sold out until staff say otherwise');
      final onSale = _item('b');
      expect(onSale.availableAt(_noon), same(onSale));
      expect(_item('c', soldOut: true, backAt: _noon).availableAt(_noon).soldOut, isFalse);
    });

    test('nextReturn is the earliest time still to come among the sold-out items', () {
      final items = [
        _item('a', soldOut: true, backAt: _noon.add(const Duration(hours: 2))),
        _item('b', soldOut: true, backAt: _noon.add(const Duration(minutes: 30))),
        _item('c', soldOut: true, backAt: _noon.subtract(const Duration(hours: 1))),
        _item('d', backAt: _noon.add(const Duration(minutes: 1))),
        _item('e', soldOut: true),
      ];
      expect(MenuItem.nextReturn(items, _noon), _noon.add(const Duration(minutes: 30)));
      expect(MenuItem.nextReturn([_item('x', soldOut: true)], _noon), isNull);
    });
  });

  group('withReturns', () {
    test('sends the menu again when the next item is due back, without a new snapshot', () async {
      var now = _noon;
      final source = StreamController<List<MenuItem>>();
      final seen = <List<bool>>[];
      final sub = withReturns(
        source.stream,
        clock: () => now,
      ).listen((items) => seen.add([for (final i in items) i.soldOut]));

      source.add([_item('a', soldOut: true, backAt: _noon.add(const Duration(milliseconds: 300))), _item('b')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(seen.single, [true, false], reason: 'a is still sold out');

      now = _noon.add(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(seen.last, [false, false], reason: 'the timer sent the menu again once a was due');
      await sub.cancel();
      await source.close();
    });

    test('passes errors on and stops with its source', () async {
      final source = StreamController<List<MenuItem>>();
      final errors = <Object>[];
      var done = false;
      withReturns(source.stream).listen((_) {}, onError: errors.add, onDone: () => done = true);
      source.addError(StateError('lost'));
      await source.close();
      await Future<void>.delayed(Duration.zero);
      expect((errors.single as StateError).message, 'lost');
      expect(done, isTrue);
    });
  });
}
