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

HomeViewModel make({MenuService? menu, DevRemoteConfigService? rc, DevCartService? cart, DevAnalyticsService? analytics}) =>
    HomeViewModel(
      menu: menu ?? DevMenuService(),
      cart: cart ?? DevCartService(),
      remoteConfig: rc ?? DevRemoteConfigService(),
      analytics: analytics ?? DevAnalyticsService(),
      uid: 'u1',
    );

void main() {
  test('bắt đầu ở loading rồi có dữ liệu; loại món hết hàng, giữ món tối đa 5 phút', () async {
    final vm = make();
    expect(vm.state, isA<ViewLoading<List<MenuItem>>>());
    await Future<void>.delayed(Duration.zero);
    final items = vm.state.dataOrNull!;
    expect(items.every((e) => !e.soldOut && e.prepMinutes <= 5), isTrue);
    expect(items.map((e) => e.id), ['m1', 'm2', 'm3']); // khớp 3 món trên Figma S02
    vm.dispose();
  });

  test('chip loại món: lấy từ thực đơn và lọc danh sách món nhanh', () async {
    final vm = make();
    await Future<void>.delayed(Duration.zero);
    expect(vm.categories, ['Tacos', 'Mì trộn', 'Đồ uống']);
    expect(vm.selectedCategory, isNull);

    vm.selectCategory('Đồ uống');
    expect(vm.state.dataOrNull!.map((e) => e.id), ['m3']);
    vm.selectCategory(null);
    expect(vm.state.dataOrNull, hasLength(3));
    vm.dispose();
  });

  test('chọn loại mà không có món nhanh thì ra trạng thái rỗng kèm lời nhắn theo mục', () async {
    final vm = make();
    await Future<void>.delayed(Duration.zero);
    vm.selectCategory('Món không tồn tại');
    expect(vm.state, isA<ViewEmpty<List<MenuItem>>>());
    expect((vm.state as ViewEmpty<List<MenuItem>>).message, 'Chưa có món nhanh trong mục này');
    vm.dispose();
  });

  test('header: lấy kiosk đang mở đầu tiên và dòng trạng thái chờ', () async {
    final vm = make();
    await Future<void>.delayed(Duration.zero);
    expect(vm.kiosk!.id, 'q9-t2');
    expect(vm.kioskStatus, 'Sẵn sàng · chờ 5–7 phút');
    vm.dispose();
  });

  test('số món trong giỏ cộng theo số lượng và cập nhật khi thêm', () async {
    final cart = DevCartService();
    final vm = make(cart: cart);
    await Future<void>.delayed(Duration.zero);
    expect(vm.cartCount, 0);
    await vm.addToCart(vm.state.dataOrNull!.first);
    await vm.addToCart(vm.state.dataOrNull!.first);
    await Future<void>.delayed(Duration.zero);
    expect(vm.cartCount, 2);
    vm.dispose();
  });

  test('giới hạn số món lấy từ Remote Config', () async {
    final rc = DevRemoteConfigService()..values['quick_items_limit'] = 1;
    final vm = make(rc: rc);
    await Future<void>.delayed(Duration.zero);
    expect(vm.state.dataOrNull, hasLength(1));
    vm.dispose();
  });

  test('giới hạn bằng 0 thì ra trạng thái rỗng', () async {
    final rc = DevRemoteConfigService()..values['quick_items_limit'] = 0;
    final vm = make(rc: rc);
    await Future<void>.delayed(Duration.zero);
    expect(vm.state, isA<ViewEmpty<List<MenuItem>>>());
    vm.dispose();
  });

  test('lỗi mạng thì ra trạng thái error', () async {
    final vm = make(menu: _FailingMenu());
    await Future<void>.delayed(Duration.zero);
    expect(vm.state, isA<ViewError<List<MenuItem>>>());
    vm.dispose();
  });

  test('thêm vào giỏ ghi giỏ hàng và sự kiện add_to_cart', () async {
    final cart = DevCartService();
    final analytics = DevAnalyticsService();
    final vm = make(cart: cart, analytics: analytics);
    await Future<void>.delayed(Duration.zero);
    await vm.addToCart(vm.state.dataOrNull!.first);
    final items = await cart.watchCart('u1').first;
    expect(items, hasLength(1));
    expect(analytics.events.single.name, 'add_to_cart');
    expect(analytics.events.single.params!['source'], 'home');
    vm.dispose();
  });
}
