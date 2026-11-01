import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/menu/view_models/item_detail_view_model.dart';
import 'package:breakbite/ui/menu/view_models/menu_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

class _FailingMenu extends FakeMenuRepository {
  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) => Stream.error(Exception('offline'));
}

void main() {
  group('MenuViewModel', () {
    MenuViewModel build({FakeMenuRepository? menu, FakeCartRepository? cart, FakeAnalyticsService? analytics}) =>
        MenuViewModel(
          menu: menu ?? FakeMenuRepository(),
          cart: cart ?? FakeCartRepository(),
          session: InMemorySessionRepository(),
          analytics: analytics ?? FakeAnalyticsService(),
          crash: FakeCrashService(),
          uid: 'u1',
          clock: () => DateTime(2026, 11, 2, 10),
        );

    test('lists the whole menu of the selected kiosk with sold-out items last', () async {
      final vm = build();
      expect(vm.state, isA<ViewLoading<List<MenuItem>>>());
      await pumpEventQueue();
      expect(vm.kiosk?.id, 'q9-t2');
      expect(vm.state.dataOrNull!.map((e) => e.id), ['m1', 'm2', 'm3', 'm4']);
      expect(vm.kioskStatus, 'Mở · chờ 5–7 phút');
      vm.dispose();
    });

    test('search ignores accents and case; filters narrow by type and time', () async {
      final vm = build();
      await pumpEventQueue();
      vm.search('TRA DAO');
      expect(vm.state.dataOrNull!.map((e) => e.id), ['m3']);
      vm.search('');
      vm.choose(MenuFilter.drink);
      expect(vm.state.dataOrNull!.map((e) => e.id), ['m3']);
      vm.choose(MenuFilter.quick);
      expect(vm.state.dataOrNull!.map((e) => e.id), ['m1', 'm2', 'm3', 'm4']);
      vm.choose(MenuFilter.quick);
      expect(vm.filter, MenuFilter.all);
      vm.dispose();
    });

    test('no match is an empty state that says filters are on, and clearing them brings the menu back', () async {
      final vm = build();
      await pumpEventQueue();
      vm.search('pizza');
      expect(vm.state, isA<ViewEmpty<List<MenuItem>>>());
      expect((vm.state as ViewEmpty<List<MenuItem>>).message, MenuViewModel.noMatchMessage);
      expect(vm.filtering, isTrue);
      vm.clearFilters();
      expect(vm.state.dataOrNull, hasLength(4));
      vm.dispose();
    });

    test('adding and changing quantities goes to the cart and is logged with the menu source', () async {
      final cart = FakeCartRepository();
      final analytics = FakeAnalyticsService();
      final vm = build(cart: cart, analytics: analytics);
      await pumpEventQueue();
      final tacos = vm.state.dataOrNull!.first;
      await vm.addToCart.execute(tacos);
      await vm.changeQuantity(tacos, 1);
      await pumpEventQueue();
      expect(vm.quantityOf('m1'), 2);
      expect(vm.cartCount, 2);
      expect(cart.current('u1').items.single.quantity, 2);
      expect(analytics.events.map((e) => e.params!['source']), everyElement('menu'));
      vm.dispose();
    });

    test('a menu that cannot load is an error state with the reason', () async {
      final vm = build(menu: _FailingMenu());
      await pumpEventQueue();
      expect(vm.state, isA<ViewError<List<MenuItem>>>());
      vm.dispose();
    });
  });

  group('ItemDetailViewModel', () {
    ItemDetailViewModel build(String id, {FakeCartRepository? cart}) => ItemDetailViewModel(
      menu: FakeMenuRepository(),
      cart: cart ?? FakeCartRepository(),
      analytics: FakeAnalyticsService(),
      crash: FakeCrashService(),
      uid: 'u1',
      itemId: id,
    );

    test('adds the chosen quantity with the kitchen note, and the label shows the line total', () async {
      final cart = FakeCartRepository();
      final vm = build('m1', cart: cart);
      await pumpEventQueue();
      expect(vm.addLabel, 'Thêm vào giỏ · 39.000đ');
      expect(vm.canDecrease, isFalse);
      vm
        ..changeQuantity(1)
        ..setNote('Ít cay');
      expect(vm.addLabel, 'Thêm vào giỏ · 78.000đ');
      final result = await vm.add.execute();
      expect(result, isA<Ok<void>>());
      final line = cart.current('u1').items.single;
      expect(line.quantity, 2);
      expect(line.note, 'Ít cay');
      await pumpEventQueue();
      expect(vm.inCart, 2);
      vm.dispose();
    });

    test('adding again to a line keeps one line and replaces its note', () async {
      final cart = FakeCartRepository();
      await cart.addItem(
        'u1',
        kioskId: 'q9-t2',
        item: const CartItem(itemId: 'm1', name: 'Tacos', priceVnd: 39000, note: 'Cũ'),
      );
      final vm = build('m1', cart: cart);
      await pumpEventQueue();
      vm.setNote('Không hành');
      await vm.add.execute();
      final line = cart.current('u1').items.single;
      expect(line.quantity, 2);
      expect(line.note, 'Không hành');
      vm.dispose();
    });

    test('a sold-out item says when it is back and cannot be added', () async {
      final vm = build('m4');
      await pumpEventQueue();
      expect(vm.blocker, 'Món này đang tạm hết, có lại lúc 10:30.');
      expect(vm.canAdd, isFalse);
      vm.dispose();
    });

    test('a cart from another kiosk blocks adding with an explanation', () async {
      final cart = FakeCartRepository();
      await cart.addItem(
        'u1',
        kioskId: 'q9-t4',
        item: const CartItem(itemId: 'm5', name: 'Bánh mì', priceVnd: 22000),
      );
      final vm = build('m1', cart: cart);
      await pumpEventQueue();
      expect(vm.blocker, ItemDetailViewModel.otherKioskMessage);
      expect(vm.canAdd, isFalse);
      vm.dispose();
    });

    test('an unknown item is the empty state', () async {
      final vm = build('nope');
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<MenuItem>>());
      vm.dispose();
    });
  });
}
