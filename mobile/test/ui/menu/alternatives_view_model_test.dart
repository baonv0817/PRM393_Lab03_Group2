import 'package:breakbite/ui/menu/view_models/alternatives_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

class _FailingMenu extends FakeMenuRepository {
  @override
  Stream<List<MenuItem>> watchMenu(String kioskId, {bool includeArchived = false}) =>
      Stream.error(Exception('offline'));
}

MenuItem _item(
  String id, {
  String? name,
  int prep = 4,
  int price = 35000,
  ItemCategory category = ItemCategory.food,
  bool soldOut = false,
  DateTime? again,
}) => MenuItem(
  id: id,
  name: name ?? id.toUpperCase(),
  priceVnd: price,
  category: category,
  prepMinutes: prep,
  soldOut: soldOut,
  kioskId: 'q9-t2',
  availableAgainAt: again,
);

void main() {
  group('AlternativesViewModel', () {
    AlternativesViewModel build(
      String id, {
      FakeMenuRepository? menu,
      FakeCartRepository? cart,
      FakeAnalyticsService? analytics,
    }) => AlternativesViewModel(
      menu: menu ?? FakeMenuRepository(),
      cart: cart ?? FakeCartRepository(),
      analytics: analytics ?? FakeAnalyticsService(),
      crash: FakeCrashService(),
      uid: 'u1',
      itemId: id,
    );

    test('shows the sold-out item, when it is back and in-stock items of its kiosk to take its place', () async {
      final vm = build('m4');
      expect(vm.state, isA<ViewLoading<AlternativesData>>());
      await pumpEventQueue();
      final data = vm.state.dataOrNull!;
      expect(data.item.id, 'm4');
      expect(AlternativesViewModel.availabilityMessage(data.item), 'Có lại lúc 10:30');
      expect(vm.title, 'Món tạm hết');
      // Same category (food), same kiosk, in stock: Tacos Bò (4 phút, like the sold-out item) before Mì trộn (5 phút).
      expect(data.suggestions.map((e) => e.id), ['m1', 'm2']);
      vm.dispose();
    });

    test('never suggests the item itself, a sold-out item, another category or another kiosk', () async {
      final vm = build('m4');
      await pumpEventQueue();
      final ids = vm.state.dataOrNull!.suggestions.map((e) => e.id);
      expect(ids, isNot(contains('m4'))); // the item itself
      expect(ids, isNot(contains('m3'))); // a drink
      expect(ids, isNot(contains('m5'))); // Kiosk Q9 · Tầng 4
      vm.dispose();
    });

    test('suggest puts the closest preparation time first, then the closest price, then the name', () {
      final sold = _item('sold', prep: 4, price: 35000, soldOut: true);
      final menu = [
        sold,
        _item('far', prep: 9, price: 35000),
        _item('near', prep: 5, price: 35000),
        _item('same', prep: 4, price: 36000),
      ];
      expect(AlternativesViewModel.suggest(sold, menu).map((e) => e.id), ['same', 'near']);

      final tied = [
        sold,
        _item('a', prep: 4, price: 40000),
        _item('c', prep: 4, price: 36000),
        _item('b', prep: 4, price: 34000),
      ];
      // Prices 1.000đ away on both sides tie, so the name decides; the dearer-by-5.000đ item comes last.
      expect(AlternativesViewModel.suggest(sold, tied).map((e) => e.id), ['b', 'c']);
    });

    test('offers at most two items', () {
      final sold = _item('sold', soldOut: true);
      final menu = [sold, for (var i = 0; i < 5; i++) _item('x$i', price: 30000 + i)];
      expect(AlternativesViewModel.suggest(sold, menu), hasLength(AlternativesViewModel.maxSuggestions));
    });

    test('an item with no time to be back says so', () {
      expect(AlternativesViewModel.availabilityMessage(_item('x', soldOut: true)), 'Chưa có giờ bán lại');
    });

    test('with nothing else in stock the screen has no suggestions', () async {
      final menu = FakeMenuRepository();
      await menu.setSoldOut('m1', true);
      await menu.setSoldOut('m2', true);
      final vm = build('m4', menu: menu);
      await pumpEventQueue();
      expect(vm.state, isA<ViewData<AlternativesData>>());
      expect(vm.state.dataOrNull!.suggestions, isEmpty);
      vm.dispose();
    });

    test('follows the menu live: a suggestion that sells out disappears', () async {
      final menu = FakeMenuRepository();
      final vm = build('m4', menu: menu);
      await pumpEventQueue();
      expect(vm.state.dataOrNull!.suggestions.map((e) => e.id), ['m1', 'm2']);
      await menu.setSoldOut('m1', true);
      await pumpEventQueue();
      expect(vm.state.dataOrNull!.suggestions.map((e) => e.id), ['m2']);
      vm.dispose();
    });

    test('when the item comes back the title and the line say so', () async {
      final menu = FakeMenuRepository();
      final vm = build('m4', menu: menu);
      await pumpEventQueue();
      await menu.setSoldOut('m4', false);
      await pumpEventQueue();
      final item = vm.state.dataOrNull!.item;
      expect(item.soldOut, isFalse);
      expect(vm.title, 'Món đã có lại');
      expect(AlternativesViewModel.availabilityMessage(item), 'Món này đã có lại, bạn có thể đặt ngay.');
      vm.dispose();
    });

    test('an unknown item is the empty state with the reason', () async {
      final vm = build('nope');
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<AlternativesData>>());
      expect((vm.state as ViewEmpty<AlternativesData>).message, 'Không tìm thấy món.');
      vm.dispose();
    });

    test('a menu that cannot load is an error state', () async {
      final vm = build('m4', menu: _FailingMenu());
      await pumpEventQueue();
      expect(vm.state, isA<ViewError<AlternativesData>>());
      expect((vm.state as ViewError<AlternativesData>).message, AlternativesViewModel.loadErrorMessage);
      vm.dispose();
    });

    test('adding a suggestion goes to the cart and is logged with the alternatives source', () async {
      final cart = FakeCartRepository();
      final analytics = FakeAnalyticsService();
      final vm = build('m4', cart: cart, analytics: analytics);
      await pumpEventQueue();
      final suggestion = vm.state.dataOrNull!.suggestions.first;
      final result = await vm.addToCart.execute(suggestion);
      expect(result, isA<Ok<void>>());
      await vm.changeQuantity(suggestion, 1);
      await pumpEventQueue();
      expect(vm.quantityOf(suggestion.id), 2);
      expect(vm.cartCount, 2);
      expect(cart.current('u1').items.single.itemId, suggestion.id);
      expect(analytics.events.map((e) => e.params!['source']), everyElement('alternatives'));
      vm.dispose();
    });

    test('a cart from another kiosk blocks adding', () async {
      final cart = FakeCartRepository();
      await cart.addItem(
        'u1',
        kioskId: 'q9-t4',
        item: const CartItem(itemId: 'm5', name: 'Bánh mì', priceVnd: 22000),
      );
      final vm = build('m4', cart: cart);
      await pumpEventQueue();
      expect(vm.blocksAdd(vm.state.dataOrNull!.suggestions.first), isTrue);
      vm.dispose();
    });
  });
}
