import 'package:breakbite/ui/favorites/view_models/favorites_view_model.dart';
import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

const _tacos = MenuItem(
  id: 'm1',
  dishId: 'tacos-bo',
  name: 'Combo Tacos Bò Phô Mai',
  priceVnd: 39000,
  category: ItemCategory.food,
  prepMinutes: 4,
  kioskId: 'q9-t2',
);
const _tea = MenuItem(
  id: 'm3',
  dishId: 'tra-dao',
  name: 'Trà Đào Chanh Sả',
  priceVnd: 20000,
  category: ItemCategory.drink,
  prepMinutes: 2,
  kioskId: 'q9-t2',
);
const _breadOfOtherKiosk = MenuItem(
  id: 'm5',
  dishId: 'banh-mi',
  name: 'Bánh Mì Chả Lụa Trứng',
  priceVnd: 22000,
  category: ItemCategory.food,
  prepMinutes: 3,
  kioskId: 'q9-t4',
);
const _soldOut = MenuItem(
  id: 'm4',
  dishId: 'tacos-ga',
  name: 'Tacos Gà Giòn Sốt Cay',
  priceVnd: 35000,
  category: ItemCategory.food,
  prepMinutes: 4,
  soldOut: true,
  kioskId: 'q9-t2',
);

class _Setup {
  _Setup() {
    session.selectKiosk('q9-t2');
  }

  final favorites = FakeFavoriteRepository();
  final cart = FakeCartRepository();
  final orders = FakeOrderRepository();
  final session = InMemorySessionRepository();
  final analytics = FakeAnalyticsService();

  FavoritesViewModel vm() => FavoritesViewModel(
    favorites: favorites,
    menu: FakeMenuRepository(),
    cart: cart,
    orders: orders,
    session: session,
    analytics: analytics,
    crash: FakeCrashService(),
    uid: 'u',
  );
}

void main() {
  group('Favorite', () {
    test('the dish id is shared by kiosks: the stored dishId, else the id without the kiosk prefix', () {
      expect(Favorite.dishIdOf(_tacos), 'tacos-bo');
      const noDish = MenuItem(
        id: 'q9-t2-banh',
        name: 'B',
        priceVnd: 1,
        category: ItemCategory.food,
        prepMinutes: 1,
        kioskId: 'q9-t2',
      );
      expect(Favorite.dishIdOf(noDish), 'banh');
      expect(Favorite.of(_tacos).matches(_tacos), isTrue);
      expect(Favorite.of(_tacos).matches(_tea), isFalse);
    });

    test('hearting twice keeps one favorite, the newest first; removing a missing one is fine', () async {
      final repo = FakeFavoriteRepository();
      await repo.add('u', _tacos);
      await repo.add('u', _tea);
      await repo.add('u', _tacos);
      expect(repo.of('u').map((f) => f.dishId), ['tra-dao', 'tacos-bo']);
      expect(await repo.remove('u', 'nope'), isA<Ok<void>>());
      await repo.remove('u', 'tra-dao');
      expect(repo.of('u').map((f) => f.dishId), ['tacos-bo']);
      expect(repo.of('someone-else'), isEmpty, reason: 'favorites belong to their owner');
    });
  });

  group('FavoritesViewModel (S13)', () {
    test('is loading, then empty with an explanation when nothing is hearted', () async {
      final s = _Setup();
      final vm = s.vm();
      expect(vm.state, isA<ViewLoading<List<FavoriteEntry>>>());
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<List<FavoriteEntry>>>());
      expect((vm.state as ViewEmpty).message, FavoritesViewModel.emptyMessage);
    });

    test(
      'takes the price and stock from today\'s menu, puts what is on sale first and marks what is not sold here',
      () async {
        final s = _Setup();
        await s.favorites.add('u', _breadOfOtherKiosk);
        await s.favorites.add('u', _soldOut);
        await s.favorites.add('u', _tacos);
        final vm = s.vm();
        await pumpEventQueue();

        final entries = (vm.state as ViewData<List<FavoriteEntry>>).data;
        expect(entries.map((e) => e.favorite.dishId), ['tacos-bo', 'tacos-ga', 'banh-mi']);
        expect(entries.map((e) => e.available), [true, false, false]);
        expect(entries.last.item, isNull, reason: 'the other kiosk\'s bread is not on this menu');
        expect(entries.first.item?.priceVnd, 39000);
      },
    );

    test('the filter keeps one kind and says so when there is none', () async {
      final s = _Setup();
      await s.favorites.add('u', _tacos);
      final vm = s.vm();
      await pumpEventQueue();

      vm.setFilter(FavoritesFilter.drink);
      expect((vm.state as ViewEmpty).message, 'Chưa có đồ uống yêu thích.');
      vm.setFilter(FavoritesFilter.food);
      expect((vm.state as ViewData<List<FavoriteEntry>>).data, hasLength(1));
    });

    test('counts how many times a dish was ordered from delivered orders only', () async {
      final s = _Setup();
      await s.favorites.add('u', _tacos);
      final delivered = await placeTestOrder(
        s.orders,
        uid: 'u',
        items: const [CartItem(itemId: 'm1', name: 'Combo', priceVnd: 39000, quantity: 2)],
      );
      await s.orders.accept(s.orders.all.single, readyIn: const Duration(minutes: 3));
      await s.orders.markReady(s.orders.all.single);
      await s.orders.deliver(s.orders.all.single);
      await placeTestOrder(
        s.orders,
        uid: 'u',
        items: const [CartItem(itemId: 'm1', name: 'Combo', priceVnd: 39000)],
      );
      final vm = s.vm();
      await pumpEventQueue();

      expect(delivered, isNotEmpty);
      expect((vm.state as ViewData<List<FavoriteEntry>>).data.single.orderedTimes, 2);
    });

    test('adds a dish to the cart and refuses to mix kiosks in one cart', () async {
      final s = _Setup();
      await s.favorites.add('u', _tacos);
      final vm = s.vm();
      await pumpEventQueue();

      expect(await vm.addToCart(_tacos), isA<Ok<void>>());
      await pumpEventQueue();
      expect(vm.cartCount, 1);
      expect(vm.quantityOf(_tacos), 1);
      expect(vm.blocksAdd(_breadOfOtherKiosk), isTrue);
    });

    test('removing takes the row away; a failed removal is returned and the row stays', () async {
      final s = _Setup();
      await s.favorites.add('u', _tacos);
      final vm = s.vm();
      await pumpEventQueue();

      s.favorites.failNextWrite = const NetworkException();
      expect(await vm.remove(s.favorites.of('u').single), isA<Err<void>>());
      expect(s.favorites.of('u'), hasLength(1));
      expect(await vm.remove(s.favorites.of('u').single), isA<Ok<void>>());
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<List<FavoriteEntry>>>());
    });
  });
}
