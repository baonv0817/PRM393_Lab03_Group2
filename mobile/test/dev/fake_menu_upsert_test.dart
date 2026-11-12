import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fakes/fakes.dart';

void main() {
  group('FakeMenuRepository.upsertItem', () {
    const draft = MenuItem(
      id: '',
      name: 'Bánh Flan Caramel',
      priceVnd: 15000,
      category: ItemCategory.other,
      prepMinutes: 1,
      kioskId: 'q9-t2',
    );

    test('refuses a new item whose name is already on the menu and keeps the first one as it is', () async {
      final menu = FakeMenuRepository();
      final id = (await menu.upsertItem(draft) as Ok<String>).value;

      final again = await menu.upsertItem(draft.copyWith(priceVnd: 1));

      expect((again as Err<String>).error, isA<ValidationException>());
      expect((await menu.getItem(id) as Ok<MenuItem>).value.priceVnd, 15000);
    });

    test('still lets the item that exists be edited with its id', () async {
      final menu = FakeMenuRepository();
      final id = (await menu.upsertItem(draft) as Ok<String>).value;
      final stored = (await menu.getItem(id) as Ok<MenuItem>).value;

      final edited = await menu.upsertItem(stored.copyWith(priceVnd: 18000));

      expect(edited.isOk, isTrue);
      expect((await menu.getItem(id) as Ok<MenuItem>).value.priceVnd, 18000);
    });
  });
}
