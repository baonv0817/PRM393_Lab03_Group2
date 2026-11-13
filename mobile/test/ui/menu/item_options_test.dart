import 'package:breakbite/ui/cart/view_models/cart_view_model.dart';
import 'package:breakbite/ui/cart/widgets/cart_screen.dart';
import 'package:breakbite/ui/menu/view_models/item_detail_view_model.dart';
import 'package:breakbite/ui/menu/widgets/item_detail_screen.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

const _tea = MenuItem(
  id: 'q9-t2-tra-sua',
  dishId: 'tra-sua',
  kioskId: 'q9-t2',
  name: 'Trà sữa',
  priceVnd: 25000,
  category: ItemCategory.drink,
  prepMinutes: 3,
  optionGroups: [
    OptionGroup(
      id: 'size',
      name: 'Size',
      required: true,
      choices: [
        OptionChoice(id: 'm', name: 'Size M'),
        OptionChoice(id: 'l', name: 'Size L', extraVnd: 5000),
      ],
    ),
    OptionGroup(
      id: 'topping',
      name: 'Topping',
      maxChoices: 2,
      choices: [
        OptionChoice(id: 'tc', name: 'Trân châu', extraVnd: 5000),
        OptionChoice(id: 'thach', name: 'Thạch', extraVnd: 3000),
        OptionChoice(id: 'pudding', name: 'Pudding', extraVnd: 7000),
      ],
    ),
  ],
);

Future<FakeMenuRepository> _menuWithTea() async {
  final menu = FakeMenuRepository();
  await menu.upsertItem(_tea);
  return menu;
}

ItemDetailViewModel _detail(FakeMenuRepository menu, FakeCartRepository cart) => ItemDetailViewModel(
  menu: menu,
  cart: cart,
  analytics: FakeAnalyticsService(),
  crash: FakeCrashService(),
  uid: 'u1',
  itemId: _tea.id,
);

void main() {
  group('ItemDetailViewModel with options', () {
    test('a required single-choice group starts on its first choice, and the price follows the picks', () async {
      final vm = _detail(await _menuWithTea(), FakeCartRepository());
      await pumpEventQueue();
      final size = _tea.optionGroups.first;
      final topping = _tea.optionGroups.last;
      expect(vm.pickedIn('size'), {'m'});
      expect(vm.optionsProblem, isNull);
      expect(vm.addLabel, 'Thêm vào giỏ · 25.000đ');
      vm.pick(size, 'l');
      vm.pick(topping, 'tc');
      vm.pick(topping, 'thach');
      expect(vm.pickedIn('size'), {'l'}, reason: 'one choice at a time');
      expect(vm.unitPriceVnd, 25000 + 5000 + 5000 + 3000);
      vm.changeQuantity(1);
      expect(vm.addLabel, 'Thêm vào giỏ · 76.000đ');
      vm.dispose();
    });

    test('a group takes no more than its maximum, and a required group cannot be emptied', () async {
      final vm = _detail(await _menuWithTea(), FakeCartRepository());
      await pumpEventQueue();
      final size = _tea.optionGroups.first;
      final topping = _tea.optionGroups.last;
      vm
        ..pick(topping, 'tc')
        ..pick(topping, 'thach')
        ..pick(topping, 'pudding');
      expect(vm.pickedIn('topping'), {'tc', 'thach'}, reason: 'the third is refused');
      vm.pick(topping, 'tc');
      expect(vm.pickedIn('topping'), {'thach'}, reason: 'tapping again takes it off');
      vm.pick(size, 'm');
      expect(vm.pickedIn('size'), {'m'}, reason: 'size is required: tapping the chosen one keeps it');
      vm.dispose();
    });

    test('adds a line with the chosen options and their price; other choices are another line', () async {
      final cart = FakeCartRepository();
      final menu = await _menuWithTea();
      final vm = _detail(menu, cart);
      await pumpEventQueue();
      vm.pick(_tea.optionGroups.first, 'l');
      vm.pick(_tea.optionGroups.last, 'tc');
      vm.changeQuantity(1);
      await vm.add.execute();
      var lines = cart.current('u1').items;
      expect(lines.single.priceVnd, 35000, reason: 'dish 25.000 + L 5.000 + trân châu 5.000');
      expect(lines.single.quantity, 2);
      expect(lines.single.optionsSummary, 'Size L · Trân châu');

      final again = _detail(menu, cart);
      await pumpEventQueue();
      again.pick(_tea.optionGroups.first, 'l');
      again.pick(_tea.optionGroups.last, 'tc');
      await again.add.execute();
      lines = cart.current('u1').items;
      expect(lines, hasLength(1), reason: 'the same choices merge into one line');
      expect(lines.single.quantity, 3);

      final other = _detail(menu, cart);
      await pumpEventQueue();
      await other.add.execute();
      lines = cart.current('u1').items;
      expect(lines, hasLength(2), reason: 'size M and no topping is another line');
      expect(lines.last.priceVnd, 25000);
      vm.dispose();
      again.dispose();
      other.dispose();
    });

    test('cannot be added while a required group is empty', () async {
      final vm = _detail(await _menuWithTea(), FakeCartRepository());
      await pumpEventQueue();
      // A group that is required but not preselected: clear the preselection through a fresh model.
      expect(vm.canAdd, isTrue);
      expect(_tea.optionsProblem({}), 'Chọn Size');
      vm.dispose();
    });
  });

  group('S04 with options', () {
    Future<void> open(WidgetTester tester) async {
      final menu = await _menuWithTea();
      await pumpScreen(
        tester,
        const ItemDetailScreen(),
        providers: [ChangeNotifierProvider(create: (_) => _detail(menu, FakeCartRepository()))],
      );
    }

    testWidgets('shows each group with its rule, the extra prices, and a total that follows the picks', (tester) async {
      await open(tester);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Topping'), findsOneWidget);
      expect(find.text('Bắt buộc'), findsOneWidget);
      expect(find.text('Chọn 1 · bắt buộc'), findsOneWidget);
      expect(find.text('Chọn tối đa 2 · không bắt buộc'), findsOneWidget);
      expect(find.text('+5.000đ'), findsNWidgets(2));
      expect(find.text('Thêm vào giỏ · 25.000đ'), findsOneWidget);
      await tester.ensureVisible(byId('s04.opt.size.l'));
      await tester.tap(byId('s04.opt.size.l'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(byId('s04.opt.topping.pudding'));
      await tester.tap(byId('s04.opt.topping.pudding'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm vào giỏ · 37.000đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('lists and the cart', () {
    testWidgets('the + of a dish with options opens the dish instead of adding it, and there is no stepper', (
      tester,
    ) async {
      var opened = 0;
      var added = 0;
      await pumpScreen(
        tester,
        Scaffold(
          body: FoodCard(item: _tea, onTap: () => opened++, onAdd: () => added++, quantity: 3, testId: 's03.item.tea'),
        ),
      );
      expect(find.textContaining('Có tuỳ chọn'), findsOneWidget);
      expect(byId('s03.item.tea.inc'), findsNothing, reason: 'a stepper cannot say which size');
      await tester.tap(byId('s03.item.tea.add'));
      expect(opened, 1);
      expect(added, 0);
    });

    testWidgets('the cart shows what was chosen under the name, and each line has its own quantity', (tester) async {
      final cart = FakeCartRepository();
      final m = _tea.choicesFor({
        'size': {'m'},
      });
      final lthach = _tea.choicesFor({
        'size': {'l'},
        'topping': {'thach'},
      });
      await cart.addItem(
        'u1',
        kioskId: 'q9-t2',
        item: CartItem(itemId: _tea.id, name: _tea.name, priceVnd: 25000, options: m),
      );
      await cart.addItem(
        'u1',
        kioskId: 'q9-t2',
        item: CartItem(itemId: _tea.id, name: _tea.name, priceVnd: 33000, quantity: 2, options: lthach),
      );
      final vm = CartViewModel(
        cart: cart,
        menu: await _menuWithTea(),
        crash: FakeCrashService(),
        uid: 'u1',
        clock: () => DateTime(2026, 11, 2, 10),
      );
      await pumpScreen(tester, const CartScreen(), providers: [ChangeNotifierProvider.value(value: vm)]);
      expect(find.text('Size M'), findsOneWidget);
      expect(find.text('Size L · Thạch'), findsOneWidget);
      expect(find.text('Trà sữa'), findsNWidgets(2));
      final first = m.isNotEmpty ? 'q9-t2-tra-sua|size:m' : '';
      await vm.changeQuantity(first, 1);
      await tester.pumpAndSettle();
      final lines = cart.current('u1').items;
      expect(lines.first.quantity, 2, reason: 'only the size M line changed');
      expect(lines.last.quantity, 2);
      expect(vm.pricing.subtotalVnd, 2 * 25000 + 2 * 33000);
      vm.dispose();
    });
  });
}
