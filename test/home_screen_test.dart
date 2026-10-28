import 'package:breakbite/dev/dev_services.dart';
import 'package:breakbite/models/models.dart';
import 'package:breakbite/screens/home_screen.dart';
import 'package:breakbite/theme/app_theme.dart';
import 'package:breakbite/viewmodels/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FailingMenu extends DevMenuService {
  @override
  Stream<List<MenuItem>> watchMenu() => Stream.error(Exception('offline'));
}

Future<({DevCartService cart, DevAnalyticsService analytics})> pumpHome(
  WidgetTester tester, {
  DevMenuService? menu,
  DevRemoteConfigService? rc,
}) async {
  final cart = DevCartService();
  final analytics = DevAnalyticsService();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: ChangeNotifierProvider(
        create: (_) => HomeViewModel(
          menu: menu ?? DevMenuService(),
          cart: cart,
          remoteConfig: rc ?? DevRemoteConfigService(),
          analytics: analytics,
          uid: 'u1',
        ),
        child: const HomeScreen(),
      ),
    ),
  );
  return (cart: cart, analytics: analytics);
}

void main() {
  testWidgets('hiện loading rồi danh sách món nhanh, bỏ món hết hàng và món làm lâu', (tester) async {
    await pumpHome(tester);
    expect(find.text('Đang tải…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Đang tải…'), findsNothing);
    expect(find.text('Món nhanh dưới 5 phút'), findsOneWidget);
    expect(find.text('Combo Tacos Bò Phô Mai'), findsOneWidget);
    expect(find.text('Mì Trộn Gà Cay Hàn Quốc'), findsOneWidget); // 5 phút vẫn nằm trong mục nhanh (Figma)
    expect(find.text('Trà Đào Chanh Sả'), findsOneWidget);
    expect(find.text('Tacos Gà Giòn Sốt Cay'), findsNothing); // hết hàng
  });

  testWidgets('header hiện kiosk, trạng thái chờ, thông báo và giỏ hàng', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    expect(find.text('Kiosk Q9 · Tầng 2'), findsOneWidget);
    expect(find.text('Sẵn sàng · chờ 5–7 phút'), findsOneWidget);
    expect(find.byTooltip('Thông báo'), findsOneWidget);
    expect(find.byTooltip('Giỏ hàng, trống'), findsOneWidget);
  });

  testWidgets('có ô tìm kiếm, chip loại món và nút Đặt lại', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    expect(find.text('Tìm Tacos, Mì trộn, Đồ uống...'), findsOneWidget);
    for (final label in ['Tất cả', 'Tacos', 'Mì trộn', 'Đồ uống']) {
      expect(find.text(label), findsOneWidget);
    }
    // Nút Đặt lại nằm cuối danh sách: cuộn tới mới thấy.
    await tester.scrollUntilVisible(find.text('Đặt lại đơn gần đây'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Đặt lại đơn gần đây'), findsOneWidget);
  });

  testWidgets('chạm chip Đồ uống thì chỉ còn món đồ uống', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đồ uống'));
    await tester.pumpAndSettle();
    expect(find.text('Trà Đào Chanh Sả'), findsOneWidget);
    expect(find.text('Combo Tacos Bò Phô Mai'), findsNothing);
    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Combo Tacos Bò Phô Mai'), findsOneWidget);
  });

  testWidgets('banner Combo Giờ Vàng theo Remote Config', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    expect(find.text('Combo Giờ Vàng –15%'), findsOneWidget);
    expect(find.text('Đặt ngay'), findsOneWidget);
  });

  testWidgets('tắt banner trong Remote Config thì banner biến mất', (tester) async {
    await pumpHome(tester, rc: DevRemoteConfigService()..values['promo_banner_enabled'] = false);
    await tester.pumpAndSettle();
    expect(find.text('Combo Giờ Vàng –15%'), findsNothing);
  });

  testWidgets('giới hạn 0 thì hiện trạng thái rỗng', (tester) async {
    await pumpHome(tester, rc: DevRemoteConfigService()..values['quick_items_limit'] = 0);
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
}
