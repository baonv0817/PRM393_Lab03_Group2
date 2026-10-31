import '../../../dev/fakes/fakes.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/home/widgets/home_screen.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/home/view_models/home_view_model.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FailingMenu extends FakeMenuRepository {
  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) => Stream.error(Exception('offline'));
}

typedef Harness = ({FakeCartRepository cart, FakeAnalyticsService analytics, FakeOrderRepository orders});

Future<Harness> pumpHome(
  WidgetTester tester, {
  FakeMenuRepository? menu,
  FakeRemoteConfigService? rc,
  FakeOrderRepository? orders,
}) async {
  final cart = FakeCartRepository();
  final analytics = FakeAnalyticsService();
  final orderService = orders ?? FakeOrderRepository();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: ChangeNotifierProvider(
        create: (_) => HomeViewModel(
          menu: menu ?? FakeMenuRepository(),
          cart: cart,
          orders: orderService,
          remoteConfig: rc ?? FakeRemoteConfigService(),
          analytics: analytics,
          uid: 'u1',
        ),
        child: const HomeScreen(),
      ),
    ),
  );
  return (cart: cart, analytics: analytics, orders: orderService);
}

void main() {
  testWidgets('hiện loading rồi danh sách món nhanh, bỏ món hết hàng', (tester) async {
    await pumpHome(tester);
    expect(find.text('Đang tải…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Đang tải…'), findsNothing);
    expect(find.text('Món nhanh · tối đa 5 phút'), findsOneWidget);
    expect(find.text('Combo Tacos Bò Phô Mai'), findsOneWidget);
    expect(find.text('Mì Trộn Gà Cay Hàn Quốc'), findsOneWidget); // 5 phút vẫn là món nhanh
    expect(find.text('Trà Đào Chanh Sả'), findsOneWidget);
    expect(find.text('Tacos Gà Giòn Sốt Cay'), findsNothing); // hết hàng
  });

  testWidgets('mỗi món nhanh có ảnh món thật (không dùng logo giữ chỗ)', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemImage), findsNWidgets(3));
    expect(find.byType(Image), findsNWidgets(3));
    expect(find.byType(BreakBiteLogo), findsNothing);
  });

  testWidgets('header hiện kiosk, trạng thái chờ, thông báo và giỏ hàng', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    expect(find.text('Kiosk Q9 · Tầng 2'), findsOneWidget);
    expect(find.text('Sẵn sàng · chờ 5–7 phút'), findsOneWidget);
    expect(find.byTooltip('Thông báo'), findsOneWidget);
    expect(find.byTooltip('Giỏ hàng, trống'), findsOneWidget);
  });

  testWidgets('có ô tìm kiếm; đã bỏ chip loại món và nút phụ trong banner', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    expect(find.text('Tìm Tacos, Mì trộn, Đồ uống...'), findsOneWidget);
    expect(find.byType(AppChip), findsNothing);
    expect(find.text('Đặt ngay'), findsNothing);
  });

  testWidgets('banner Combo Giờ Vàng theo Remote Config', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    expect(find.text('Combo Giờ Vàng –15%'), findsOneWidget);
  });

  testWidgets('tắt banner trong Remote Config thì banner biến mất', (tester) async {
    await pumpHome(tester, rc: FakeRemoteConfigService()..values['promo_banner_enabled'] = false);
    await tester.pumpAndSettle();
    expect(find.text('Combo Giờ Vàng –15%'), findsNothing);
  });

  testWidgets('giới hạn 0 thì hiện trạng thái rỗng', (tester) async {
    await pumpHome(tester, rc: FakeRemoteConfigService()..values['quick_items_limit'] = 0);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có món nhanh lúc này'), findsOneWidget);
  });

  testWidgets('lỗi mạng hiện thông báo và nút Thử lại', (tester) async {
    await pumpHome(tester, menu: _FailingMenu());
    await tester.pumpAndSettle();
    expect(find.text('Không tải được thực đơn. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('bấm + ghi vào giỏ, ghi sự kiện và hiện thông báo "Đã thêm"', (tester) async {
    final h = await pumpHome(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thêm Combo Tacos Bò Phô Mai vào giỏ'));
    await tester.pumpAndSettle();

    expect(find.text('Đã thêm Combo Tacos Bò Phô Mai vào giỏ'), findsOneWidget);
    expect(find.text('Xem giỏ'), findsOneWidget);
    expect(find.byTooltip('Giỏ hàng, 1 món'), findsOneWidget); // huy hiệu giỏ cập nhật
    final items = await h.cart.watchCart('u1').first;
    expect(items.single.itemId, 'm1');
    expect(h.analytics.events.single.name, 'add_to_cart');
  });

  testWidgets('vùng bấm nút + đạt tối thiểu 48 dp', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byTooltip('Thêm Combo Tacos Bò Phô Mai vào giỏ'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  group('Đặt lại đơn gần đây', () {
    testWidgets('chưa có đơn thì không hiện nút Đặt lại', (tester) async {
      await pumpHome(tester);
      await tester.pumpAndSettle();
      expect(find.text('Đặt lại đơn gần đây'), findsNothing);
    });

    testWidgets('đã có đơn thì hiện tóm tắt; bấm thì thêm món vào giỏ', (tester) async {
      final orders = FakeOrderRepository();
      await orders.createOrder(
        uid: 'u1',
        items: const [
          CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000),
          CartItem(itemId: 'm3', name: 'Trà Đào Chanh Sả', priceVnd: 20000),
        ],
        totalVnd: 59000,
        method: PaymentMethod.momo,
        kioskId: 'q9-t2',
      );
      final h = await pumpHome(tester, orders: orders);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Đặt lại đơn gần đây'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Combo Tacos Bò Phô Mai + 1 món · 59.000đ'), findsOneWidget);

      await tester.tap(find.text('Đặt lại đơn gần đây'));
      await tester.pumpAndSettle();
      expect(find.text('Đã thêm 2 món của đơn gần đây vào giỏ'), findsOneWidget);
      expect((await h.cart.watchCart('u1').first).map((e) => e.itemId), ['m1', 'm3']);
      expect(h.analytics.events.map((e) => e.name), contains('reorder'));
    });
  });
}
