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
  test('bắt đầu ở loading rồi có dữ liệu; loại món hết hàng và món làm lâu', () async {
    final vm = make();
    expect(vm.state, isA<ViewLoading<List<MenuItem>>>());
    await Future<void>.delayed(Duration.zero);
    final items = vm.state.dataOrNull!;
    expect(items.every((e) => !e.soldOut && e.prepMinutes < 5), isTrue);
    expect(items.map((e) => e.id), isNot(contains('m4')));
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
