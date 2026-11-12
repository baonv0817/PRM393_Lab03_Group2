import 'dart:async';

import 'package:breakbite/ui/home/view_models/home_view_model.dart';
import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

class _FailingMenu extends FakeMenuRepository {
  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) => Stream.error(Exception('offline'));
}

class _FailingCart extends FakeCartRepository {
  @override
  Future<Result<void>> addItem(String uid, {required String kioskId, required CartItem item}) async =>
      const Result.error(PermissionDeniedException());
}

class _ClosedFirstMenu extends FakeMenuRepository {
  @override
  Stream<List<Kiosk>> watchKiosks() => Stream.value(const [
    Kiosk(id: 'nvh-t1', name: 'Nhà văn hóa SV · Tầng 1', open: false, waitMinutes: 0),
    Kiosk(id: 'q9-t4', name: 'Kiosk Q9 · Tầng 4', open: true, waitMinutes: 10),
  ]);
}

class _NoKioskMenu extends FakeMenuRepository {
  @override
  Stream<List<Kiosk>> watchKiosks() => Stream.value(const []);
}

class _FlakyKioskMenu extends FakeMenuRepository {
  bool fail = true;

  @override
  Stream<List<Kiosk>> watchKiosks() => fail ? Stream.error(Exception('offline')) : super.watchKiosks();
}

class _SlowCart extends FakeCartRepository {
  final _gates = <Completer<void>>[];
  final written = <int>[];
  bool hold = true;
  bool failNext = false;

  @override
  Future<Result<void>> setQuantity(String uid, String itemId, int quantity) async {
    if (hold) {
      final gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    }
    if (failNext) {
      failNext = false;
      return const Result.error(NetworkException());
    }
    written.add(quantity);
    return super.setQuantity(uid, itemId, quantity);
  }

  void release() {
    hold = false;
    for (final gate in _gates) {
      if (!gate.isCompleted) gate.complete();
    }
  }
}

const _tacos = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000);
const _tea = CartItem(itemId: 'm3', name: 'Trà Đào Chanh Sả', priceVnd: 20000, quantity: 2);

HomeViewModel make({
  MenuRepository? menu,
  FakeRemoteConfigService? rc,
  FakeCartRepository? cart,
  FakeOrderRepository? orders,
  FakeAnalyticsService? analytics,
  FakeCrashService? crash,
  InMemorySessionRepository? session,
  DateTime Function()? clock,
}) => HomeViewModel(
  menu: menu ?? FakeMenuRepository(),
  cart: cart ?? FakeCartRepository(),
  orders: orders ?? FakeOrderRepository(),
  session: session ?? InMemorySessionRepository(),
  remoteConfig: rc ?? FakeRemoteConfigService(),
  analytics: analytics ?? FakeAnalyticsService(),
  crash: crash ?? FakeCrashService(),
  uid: 'u1',
  clock: clock,
);

/// The kiosk of the fake menu items (q9-t2) as the kiosk side sets it, for S21.
class _KioskMenu extends FakeMenuRepository {
  _KioskMenu(this.kiosk);

  final Kiosk kiosk;

  @override
  Stream<List<Kiosk>> watchKiosks() => Stream.value([kiosk]);
}

final _now = DateTime(2026, 11, 4, 9);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts loading then shows data; drops sold-out items, keeps items of at most 5 minutes', () async {
    final vm = make();
    expect(vm.state, isA<ViewLoading<List<MenuItem>>>());
    await settle();
    final items = vm.state.dataOrNull!;
    expect(items.every((e) => !e.soldOut && e.prepMinutes <= 5), isTrue);
    expect(items.map((e) => e.id), ['m1', 'm2', 'm3']);
    vm.dispose();
  });

  test('limits the number of items with Remote Config', () async {
    final rc = FakeRemoteConfigService()..values['quick_items_limit'] = 1;
    final vm = make(rc: rc);
    await settle();
    expect(vm.state.dataOrNull, hasLength(1));
    vm.dispose();
  });

  test('a limit of 0 gives the empty state', () async {
    final rc = FakeRemoteConfigService()..values['quick_items_limit'] = 0;
    final vm = make(rc: rc);
    await settle();
    expect(vm.state, isA<ViewEmpty<List<MenuItem>>>());
    vm.dispose();
  });

  test('a network error gives the error state and records a non-fatal error', () async {
    final crash = FakeCrashService();
    final vm = make(menu: _FailingMenu(), crash: crash);
    await settle();
    expect(vm.state, isA<ViewError<List<MenuItem>>>());
    expect(crash.errors, hasLength(1));
    vm.dispose();
  });

  test('header uses the first open kiosk and its wait-time line', () async {
    final vm = make();
    await settle();
    expect(vm.kiosk!.id, 'q9-t2');
    expect(vm.kioskStatus, 'Sẵn sàng · chờ 5–7 phút');
    vm.dispose();
  });

  test('add to cart writes the cart and the add_to_cart event; the cart count updates', () async {
    final cart = FakeCartRepository();
    final analytics = FakeAnalyticsService();
    final vm = make(cart: cart, analytics: analytics);
    await settle();
    expect(vm.cartCount, 0);
    await vm.addToCart.execute(vm.state.dataOrNull!.first);
    await vm.addToCart.execute(vm.state.dataOrNull!.first);
    await settle();
    expect(vm.cartCount, 2);
    expect((await cart.watchCart('u1').first).items.single.quantity, 2);
    expect(analytics.events.first.name, 'add_to_cart');
    expect(analytics.events.first.params!['source'], 'home');
    vm.dispose();
  });

  test('a failed cart write returns the error, logs no event and records a non-fatal error', () async {
    final analytics = FakeAnalyticsService();
    final crash = FakeCrashService();
    final vm = make(cart: _FailingCart(), analytics: analytics, crash: crash);
    await settle();
    final result = (await vm.addToCart.execute(vm.state.dataOrNull!.first))!;
    expect(result.errorOrNull, isA<PermissionDeniedException>());
    expect(analytics.events, isEmpty);
    expect(crash.errors, hasLength(1));
    vm.dispose();
  });

  group('menu per kiosk', () {
    test('only shows items of the selected kiosk (the first open one)', () async {
      final vm = make();
      await settle();
      expect(vm.kiosk!.id, 'q9-t2');
      expect(vm.state.dataOrNull!.every((e) => e.kioskId == 'q9-t2'), isTrue);
      expect(vm.state.dataOrNull!.map((e) => e.id), ['m1', 'm2', 'm3']);
      vm.dispose();
    });

    test('picks the next open kiosk when the first one is closed', () async {
      final vm = make(menu: _ClosedFirstMenu());
      await settle();
      expect(vm.kiosk!.id, 'q9-t4');
      expect(vm.state.dataOrNull!.map((e) => e.id), ['m5', 'm6']);
      vm.dispose();
    });

    test('shows the empty state when there is no kiosk', () async {
      final vm = make(menu: _NoKioskMenu());
      await settle();
      expect(vm.kiosk, isNull);
      expect(vm.state, isA<ViewEmpty<List<MenuItem>>>());
      vm.dispose();
    });

    test('a kiosk loading error gives the error state, and retry loads again', () async {
      final menu = _FlakyKioskMenu();
      final vm = make(menu: menu);
      await settle();
      expect(vm.state, isA<ViewError<List<MenuItem>>>());
      menu.fail = false;
      vm.load();
      await settle();
      expect(vm.state, isA<ViewData<List<MenuItem>>>());
      vm.dispose();
    });
  });

  group('kiosk from the session', () {
    test('uses the kiosk chosen in the session (S27) and reloads the menu when it changes', () async {
      final session = InMemorySessionRepository(selectedKioskId: 'q9-t4');
      final vm = make(session: session);
      await settle();
      expect(vm.kiosk!.id, 'q9-t4');
      expect(vm.state.dataOrNull!.map((e) => e.id), ['m5', 'm6']);

      await session.selectKiosk('q9-t2');
      await settle();
      expect(vm.kiosk!.id, 'q9-t2');
      expect(vm.state.dataOrNull!.map((e) => e.id), ['m1', 'm2', 'm3']);
      vm.dispose();
    });

    test('without a choice it picks the first open kiosk and remembers it in the session', () async {
      final session = InMemorySessionRepository();
      final vm = make(session: session);
      await settle();
      expect(session.selectedKioskId, 'q9-t2');
      vm.dispose();
    });

    test('a session kiosk that no longer exists falls back to the first open kiosk', () async {
      final session = InMemorySessionRepository(selectedKioskId: 'gone');
      final vm = make(session: session);
      await settle();
      expect(vm.kiosk!.id, 'q9-t2');
      expect(session.selectedKioskId, 'q9-t2');
      vm.dispose();
    });
  });

  test('a second tap while adding to the cart is ignored', () async {
    final cart = FakeCartRepository();
    final vm = make(cart: cart);
    await settle();
    final item = vm.state.dataOrNull!.first;
    final first = vm.addToCart.execute(item);
    final second = await vm.addToCart.execute(item);
    await first;
    expect(second, isNull);
    expect((await cart.watchCart('u1').first).items.single.quantity, 1);
    vm.dispose();
  });

  test('no error is thrown when an action finishes after the screen was closed', () async {
    final vm = make();
    await settle();
    final pending = vm.addToCart.execute(vm.state.dataOrNull!.first);
    vm.dispose();
    await expectLater(pending, completes);
  });

  group('reorder the latest order', () {
    test('with no order there is nothing to reorder and reorder returns 0', () async {
      final vm = make();
      await settle();
      expect(vm.lastOrder, isNull);
      expect((await vm.reorderLast.execute())!.valueOrNull, 0);
      vm.dispose();
    });

    test('uses the newest order that is not cancelled', () async {
      final orders = FakeOrderRepository();
      await placeTestOrder(orders, uid: 'u1', items: const [_tacos], method: PaymentMethod.momo, kioskId: 'q9-t2');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final newer = await placeTestOrder(
        orders,
        uid: 'u1',
        items: const [_tea],
        method: PaymentMethod.cash,
        kioskId: 'q9-t2',
      );
      final vm = make(orders: orders);
      await settle();
      expect(vm.lastOrder!.id, newer);

      await orders.cancelMyOrder(orders.all.firstWhere((o) => o.id == newer));
      await settle();
      expect(vm.lastOrder!.items.single.itemId, 'm1');
      vm.dispose();
    });

    test('ignores orders of other users', () async {
      final orders = FakeOrderRepository();
      await placeTestOrder(
        orders,
        uid: 'someone-else',
        items: const [_tacos],
        method: PaymentMethod.momo,
        kioskId: 'q9-t2',
      );
      final vm = make(orders: orders);
      await settle();
      expect(vm.lastOrder, isNull);
      vm.dispose();
    });

    test('reorder adds the same items and quantities to the cart and logs the reorder event', () async {
      final orders = FakeOrderRepository();
      await placeTestOrder(
        orders,
        uid: 'u1',
        items: const [_tacos, _tea],
        method: PaymentMethod.momo,
        kioskId: 'q9-t2',
      );
      final cart = FakeCartRepository();
      final analytics = FakeAnalyticsService();
      final vm = make(orders: orders, cart: cart, analytics: analytics);
      await settle();

      expect((await vm.reorderLast.execute())!.valueOrNull, 2);
      final items = (await cart.watchCart('u1').first).items;
      expect(items.map((e) => '${e.itemId}x${e.quantity}'), ['m1x1', 'm3x2']);
      expect(analytics.events.single.name, 'reorder');
      vm.dispose();
    });
  });

  test('a Remote Config change published from the console updates the quick list without a reload', () async {
    final rc = FakeRemoteConfigService();
    final vm = make(rc: rc);
    await settle();
    expect(vm.state.dataOrNull!.length, greaterThan(1));
    rc.publish(RemoteKeys.quickItemsLimit, 1);
    await settle();
    expect(vm.state.dataOrNull, hasLength(1));
    rc.publish(RemoteKeys.promoBannerEnabled, false);
    expect(vm.promoBannerEnabled, isFalse);
    vm.dispose();
  });

  test('reordering an order from another kiosk switches Home to that kiosk', () async {
    final orders = FakeOrderRepository();
    await placeTestOrder(orders, uid: 'u1', items: const [_tacos], kioskId: 'q9-t4');
    final session = InMemorySessionRepository(selectedKioskId: 'q9-t2');
    final vm = make(orders: orders, session: session);
    await settle();
    expect((await vm.reorderLast.execute())!.valueOrNull, 1);
    expect(session.selectedKioskId, 'q9-t4');
    vm.dispose();
  });

  group('quantity on the card', () {
    test('taps change the number at once, are written in order and none is lost', () async {
      final cart = _SlowCart();
      final vm = make(cart: cart);
      await settle();
      final item = vm.state.dataOrNull!.first;
      await vm.addToCart.execute(item);
      await settle();
      expect(vm.quantityOf(item.id), 1);
      final taps = [vm.changeQuantity(item, 1), vm.changeQuantity(item, 1), vm.changeQuantity(item, 1)];
      expect(vm.quantityOf(item.id), 4);
      expect(vm.cartCount, 4);
      cart.release();
      await Future.wait(taps);
      await settle();
      expect(cart.written, [4]);
      expect((await cart.watchCart('u1').first).items.single.quantity, 4);
      expect(vm.quantityOf(item.id), 4);
      vm.dispose();
    });

    test('going down to zero removes the item from the cart', () async {
      final cart = FakeCartRepository();
      final vm = make(cart: cart);
      await settle();
      final item = vm.state.dataOrNull!.first;
      await vm.addToCart.execute(item);
      await settle();
      await vm.changeQuantity(item, -1);
      await settle();
      expect(vm.quantityOf(item.id), 0);
      expect((await cart.watchCart('u1').first).isEmpty, isTrue);
      vm.dispose();
    });

    test('a failed write puts the stored number back and records the error', () async {
      final cart = _SlowCart();
      final crash = FakeCrashService();
      final vm = make(cart: cart, crash: crash);
      await settle();
      final item = vm.state.dataOrNull!.first;
      await vm.addToCart.execute(item);
      await settle();
      cart.failNext = true;
      final tap = vm.changeQuantity(item, 1);
      expect(vm.quantityOf(item.id), 2);
      cart.release();
      final result = await tap;
      expect(result, isA<Err<void>>());
      expect(vm.quantityOf(item.id), 1);
      expect(crash.errors, hasLength(1));
      vm.dispose();
    });

    test('the number stops at 99 and an item of another kiosk is flagged before adding', () async {
      final cart = FakeCartRepository();
      final vm = make(cart: cart);
      await settle();
      final item = vm.state.dataOrNull!.first;
      await cart.addItem(
        'u1',
        kioskId: item.kioskId,
        item: CartItem(itemId: item.id, name: item.name, priceVnd: item.priceVnd, quantity: 99),
      );
      await settle();
      expect(vm.canIncrease(item.id), isFalse);
      await vm.changeQuantity(item, 1);
      expect(vm.quantityOf(item.id), 99);
      expect(vm.blocksAdd(item), isFalse);
      expect(
        vm.blocksAdd(
          const MenuItem(
            id: 'x',
            name: 'X',
            priceVnd: 1000,
            category: ItemCategory.food,
            prepMinutes: 2,
            kioskId: 'q9-t4',
          ),
        ),
        isTrue,
      );
      vm.dispose();
    });
  });

  group('S21 kiosk closed', () {
    test('an open kiosk keeps the normal Home', () async {
      final vm = make(clock: () => _now);
      await settle();
      expect(vm.closed, isFalse);
      expect(vm.reopenLabel, isNull);
      vm.dispose();
    });

    test('a closed kiosk explains when it opens and previews every item in stock, not only quick ones', () async {
      final vm = make(
        menu: _KioskMenu(
          const Kiosk(id: 'q9-t2', name: 'Kiosk Q9 · Tầng 2', open: false, waitMinutes: 0, openTime: '10:30'),
        ),
        clock: () => _now,
      );
      await settle();
      expect(vm.closed, isTrue);
      expect(vm.kioskStatus, 'Đóng · mở lại 10:30');
      expect(vm.closedTitle, 'Quán đang đóng cửa');
      expect(vm.reopenLabel, 'Mở lại lúc 10:30');
      expect(vm.closedMessage, 'Mở lại lúc 10:30. Bạn xem trước thực đơn được, hoặc chọn kiosk khác để đặt món ngay.');
      expect(vm.state.dataOrNull!.map((e) => e.id), ['m1', 'm2', 'm3']);
      vm.dispose();
    });

    test("a closed kiosk without opening hours still explains, and starts with the kiosk's notice", () async {
      final vm = make(
        menu: _KioskMenu(
          const Kiosk(id: 'q9-t2', name: 'Kiosk Q9 · Tầng 2', open: false, waitMinutes: 0, notice: 'Nghỉ lễ'),
        ),
        clock: () => _now,
      );
      await settle();
      expect(vm.kioskStatus, 'Đang đóng cửa');
      expect(vm.reopenLabel, isNull);
      expect(vm.closedMessage, 'Nghỉ lễ. Bạn xem trước thực đơn được, hoặc chọn kiosk khác để đặt món ngay.');
      vm.dispose();
    });

    test('a paused kiosk says when it takes orders again; a pause that is over keeps Home normal', () async {
      final paused = make(
        menu: _KioskMenu(
          Kiosk(
            id: 'q9-t2',
            name: 'Kiosk Q9 · Tầng 2',
            open: true,
            waitMinutes: 6,
            pausedUntil: _now.add(const Duration(minutes: 15)),
          ),
        ),
        clock: () => _now,
      );
      final over = make(
        menu: _KioskMenu(
          Kiosk(
            id: 'q9-t2',
            name: 'Kiosk Q9 · Tầng 2',
            open: true,
            waitMinutes: 6,
            pausedUntil: _now.subtract(const Duration(minutes: 1)),
          ),
        ),
        clock: () => _now,
      );
      await settle();
      expect(paused.closed, isTrue);
      expect(paused.closedTitle, 'Quán tạm ngưng nhận đơn');
      expect(paused.kioskStatus, 'Tạm ngưng · nhận đơn lại lúc 09:15');
      expect(paused.reopenLabel, 'Nhận đơn lại lúc 09:15');
      expect(over.closed, isFalse);
      expect(over.kioskStatus, 'Sẵn sàng · chờ 5–7 phút');
      paused.dispose();
      over.dispose();
    });

    test('when the pause ends Home comes back on its own', () async {
      var now = _now;
      final vm = make(
        menu: _KioskMenu(
          Kiosk(
            id: 'q9-t2',
            name: 'Kiosk Q9 · Tầng 2',
            open: true,
            waitMinutes: 6,
            pausedUntil: _now.add(const Duration(milliseconds: 50)),
          ),
        ),
        clock: () => now,
      );
      await settle();
      expect(vm.closed, isTrue);
      var notified = 0;
      vm.addListener(() => notified++);
      now = _now.add(const Duration(minutes: 1));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(notified, greaterThan(0));
      expect(vm.closed, isFalse);
      vm.dispose();
    });
  });
}
