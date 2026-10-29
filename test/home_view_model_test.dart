import 'dart:async';

import 'package:breakbite/dev/dev_services.dart';
import 'package:breakbite/models/models.dart';
import 'package:breakbite/services/services.dart';
import 'package:breakbite/viewmodels/home_view_model.dart';
import 'package:breakbite/viewmodels/view_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingMenu extends DevMenuService {
  @override
  Stream<List<MenuItem>> watchMenu() => Stream.error(Exception('offline'));
}

const _tacos = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000);
const _tea = CartItem(itemId: 'm3', name: 'Trà Đào Chanh Sả', priceVnd: 20000, quantity: 2);

HomeViewModel make({
  MenuService? menu,
  DevRemoteConfigService? rc,
  DevCartService? cart,
  DevOrderService? orders,
  DevAnalyticsService? analytics,
}) =>
    HomeViewModel(
      menu: menu ?? DevMenuService(),
      cart: cart ?? DevCartService(),
      orders: orders ?? DevOrderService(),
      remoteConfig: rc ?? DevRemoteConfigService(),
      analytics: analytics ?? DevAnalyticsService(),
      uid: 'u1',
    );

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('bắt đầu ở loading rồi có dữ liệu; loại món hết hàng, giữ món tối đa 5 phút', () async {
    final vm = make();
    expect(vm.state, isA<ViewLoading<List<MenuItem>>>());
    await settle();
    final items = vm.state.dataOrNull!;
    expect(items.every((e) => !e.soldOut && e.prepMinutes <= 5), isTrue);
    expect(items.map((e) => e.id), ['m1', 'm2', 'm3']);
    vm.dispose();
  });

  test('giới hạn số món lấy từ Remote Config', () async {
    final rc = DevRemoteConfigService()..values['quick_items_limit'] = 1;
    final vm = make(rc: rc);
    await settle();
    expect(vm.state.dataOrNull, hasLength(1));
    vm.dispose();
  });

  test('giới hạn bằng 0 thì ra trạng thái rỗng', () async {
    final rc = DevRemoteConfigService()..values['quick_items_limit'] = 0;
    final vm = make(rc: rc);
    await settle();
    expect(vm.state, isA<ViewEmpty<List<MenuItem>>>());
    vm.dispose();
  });

  test('lỗi mạng thì ra trạng thái error', () async {
    final vm = make(menu: _FailingMenu());
    await settle();
    expect(vm.state, isA<ViewError<List<MenuItem>>>());
    vm.dispose();
  });

  test('header: lấy kiosk đang mở đầu tiên và dòng trạng thái chờ', () async {
    final vm = make();
    await settle();
    expect(vm.kiosk!.id, 'q9-t2');
    expect(vm.kioskStatus, 'Sẵn sàng · chờ 5–7 phút');
    vm.dispose();
  });

  test('thêm vào giỏ ghi giỏ hàng và sự kiện add_to_cart; số món trong giỏ cập nhật', () async {
    final cart = DevCartService();
    final analytics = DevAnalyticsService();
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

  group('đặt lại đơn gần đây', () {
    test('chưa có đơn thì không có đơn để đặt lại và đặt lại trả 0', () async {
      final vm = make();
      await settle();
      expect(vm.lastOrder, isNull);
      expect(await vm.reorderLast(), 0);
      vm.dispose();
    });

    test('lấy đơn mới nhất chưa huỷ, bỏ qua đơn đã huỷ', () async {
      final orders = DevOrderService();
      await orders.createOrder(uid: 'u1', items: const [_tacos], totalVnd: 39000, method: PaymentMethod.momo, kioskId: 'q9-t2');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final newer = await orders.createOrder(uid: 'u1', items: const [_tea], totalVnd: 40000, method: PaymentMethod.cash, kioskId: 'q9-t2');
      final vm = make(orders: orders);
      await settle();
      expect(vm.lastOrder!.id, newer);

      await orders.cancelOrder(newer);
      await settle();
      expect(vm.lastOrder!.items.single.itemId, 'm1'); // quay về đơn trước đó
      vm.dispose();
    });

    test('không lấy đơn của người khác', () async {
      final orders = DevOrderService();
      await orders.createOrder(uid: 'someone-else', items: const [_tacos], totalVnd: 39000, method: PaymentMethod.momo, kioskId: 'q9-t2');
      final vm = make(orders: orders);
      await settle();
      expect(vm.lastOrder, isNull);
      vm.dispose();
    });

    test('đặt lại thêm đúng các món và số lượng vào giỏ, ghi sự kiện reorder', () async {
      final orders = DevOrderService();
      await orders.createOrder(uid: 'u1', items: const [_tacos, _tea], totalVnd: 79000, method: PaymentMethod.momo, kioskId: 'q9-t2');
      final cart = DevCartService();
      final analytics = DevAnalyticsService();
      final vm = make(orders: orders, cart: cart, analytics: analytics);
      await settle();

      expect(await vm.reorderLast(), 2);
      final items = await cart.watchCart('u1').first;
      expect(items.map((e) => '${e.itemId}x${e.quantity}'), ['m1x1', 'm3x2']);
      expect(analytics.events.single.name, 'reorder');
      vm.dispose();
    });
  });
}
