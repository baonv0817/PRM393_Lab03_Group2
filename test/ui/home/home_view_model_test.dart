import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/home/view_models/home_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

class _FailingMenu extends FakeMenuRepository {
  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) => Stream.error(Exception('offline'));
}

class _FailingCart extends FakeCartRepository {
  @override
  Future<Result<void>> addItem(String uid, CartItem item) async => const Result.error(PermissionDeniedException());
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

const _tacos = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000);
const _tea = CartItem(itemId: 'm3', name: 'Trà Đào Chanh Sả', priceVnd: 20000, quantity: 2);

HomeViewModel make({
  MenuRepository? menu,
  FakeRemoteConfigService? rc,
  FakeCartRepository? cart,
  FakeOrderRepository? orders,
  FakeAnalyticsService? analytics,
  FakeCrashService? crash,
}) => HomeViewModel(
  menu: menu ?? FakeMenuRepository(),
  cart: cart ?? FakeCartRepository(),
  orders: orders ?? FakeOrderRepository(),
  remoteConfig: rc ?? FakeRemoteConfigService(),
  analytics: analytics ?? FakeAnalyticsService(),
  crash: crash ?? FakeCrashService(),
  uid: 'u1',
);

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
    await vm.addToCart(vm.state.dataOrNull!.first);
    await vm.addToCart(vm.state.dataOrNull!.first);
    await settle();
    expect(vm.cartCount, 2);
    expect((await cart.watchCart('u1').first).single.quantity, 2);
    expect(analytics.events.first.name, 'add_to_cart');
    expect(analytics.events.first.params!['source'], 'home');
    vm.dispose();
  });

  test('a failed cart write returns the error, logs no event and records a non-fatal error', () async {
    final analytics = FakeAnalyticsService();
    final crash = FakeCrashService();
    final vm = make(cart: _FailingCart(), analytics: analytics, crash: crash);
    await settle();
    final result = await vm.addToCart(vm.state.dataOrNull!.first);
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
      expect(vm.state.dataOrNull!.map((e) => e.id), ['m1', 'm2', 'm3']); // no m5, m6 from floor 4
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

  group('reorder the latest order', () {
    test('with no order there is nothing to reorder and reorder returns 0', () async {
      final vm = make();
      await settle();
      expect(vm.lastOrder, isNull);
      expect((await vm.reorderLast()).valueOrNull, 0);
      vm.dispose();
    });

    test('uses the newest order that is not cancelled', () async {
      final orders = FakeOrderRepository();
      await orders.createOrder(
        uid: 'u1',
        items: const [_tacos],
        totalVnd: 39000,
        method: PaymentMethod.momo,
        kioskId: 'q9-t2',
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final newer = (await orders.createOrder(
        uid: 'u1',
        items: const [_tea],
        totalVnd: 40000,
        method: PaymentMethod.cash,
        kioskId: 'q9-t2',
      )).valueOrNull!;
      final vm = make(orders: orders);
      await settle();
      expect(vm.lastOrder!.id, newer);

      await orders.cancelOrder(newer);
      await settle();
      expect(vm.lastOrder!.items.single.itemId, 'm1'); // falls back to the previous order
      vm.dispose();
    });

    test('ignores orders of other users', () async {
      final orders = FakeOrderRepository();
      await orders.createOrder(
        uid: 'someone-else',
        items: const [_tacos],
        totalVnd: 39000,
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
      await orders.createOrder(
        uid: 'u1',
        items: const [_tacos, _tea],
        totalVnd: 79000,
        method: PaymentMethod.momo,
        kioskId: 'q9-t2',
      );
      final cart = FakeCartRepository();
      final analytics = FakeAnalyticsService();
      final vm = make(orders: orders, cart: cart, analytics: analytics);
      await settle();

      expect((await vm.reorderLast()).valueOrNull, 2);
      final items = await cart.watchCart('u1').first;
      expect(items.map((e) => '${e.itemId}x${e.quantity}'), ['m1x1', 'm3x2']);
      expect(analytics.events.single.name, 'reorder');
      vm.dispose();
    });
  });
}
