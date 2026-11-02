import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/seller_menu/view_models/menu_item_form_view_model.dart';
import 'package:breakbite/ui/seller_menu/widgets/menu_item_form_screen.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Finder field(String id) => find.descendant(of: byId(id), matching: find.byType(TextField));

class _OfflineGet extends FakeMenuRepository {
  @override
  Future<Result<MenuItem>> getItem(String id) async => const Result.error(NetworkException());
}

class _OfflineSave extends FakeMenuRepository {
  @override
  Future<Result<String>> upsertItem(MenuItem item) async => const Result.error(NetworkException());
}

class _NeverLoads extends FakeMenuRepository {
  @override
  Future<Result<MenuItem>> getItem(String id) => Future.any(const []);
}

Future<void> _pump(
  WidgetTester tester,
  MenuRepository menu, {
  String? itemId,
  String? kioskId = 'q9-t2',
  Size size = TestScreens.narrow,
  bool settle = true,
}) async {
  // The width is the phone's; the height is tall because a ListView only builds what is on screen and
  // the test font is wider than Nunito, so the whole page would otherwise need scrolling.
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(size.width, 3200);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: itemId == null ? AppRoutes.sellerMenuNew : AppRoutes.sellerMenuEditOf(itemId),
    routes: [
      GoRoute(
        path: AppRoutes.sellerMenuNew,
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => MenuItemFormViewModel(menu: menu, crash: FakeCrashService(), kioskId: kioskId),
          child: const MenuItemFormScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.sellerMenuEdit,
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => MenuItemFormViewModel(
            menu: menu,
            crash: FakeCrashService(),
            kioskId: kioskId,
            itemId: state.pathParameters['id'],
          ),
          child: const MenuItemFormScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.sellerMenu,
        builder: (context, state) => const Scaffold(body: Text('K08')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(theme: AppTheme.light(), routerConfig: router));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

bool _saveEnabled(WidgetTester tester, String id) {
  final button = tester.widget<FilledButton>(find.descendant(of: byId(id), matching: find.byType(FilledButton)));
  return button.onPressed != null;
}

Future<void> _type(WidgetTester tester, String id, String value) async {
  await tester.enterText(field(id), value);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String id) async {
  await tester.tap(byId(id));
  await tester.pumpAndSettle();
}

Future<MenuItem> _item(FakeMenuRepository menu, String id) async => (await menu.getItem(id) as Ok<MenuItem>).value;

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide, Size(1024, 768)]) {
    testWidgets('K14 at ${size.width.round()} dp shows every field and the add button without overflow', (
      tester,
    ) async {
      await _pump(tester, FakeMenuRepository(), size: size);

      expect(find.text('Thêm món mới'), findsOneWidget);
      for (final id in ['name', 'price', 'prep', 'description']) {
        expect(byId('k14.$id'), findsOneWidget);
      }
      for (final category in ItemCategory.values) {
        expect(byId('k14.category.${category.name}'), findsOneWidget);
      }
      expect(find.text('Tên món'), findsOneWidget);
      expect(find.text('Giá bán'), findsOneWidget);
      expect(find.text('Thời gian chuẩn bị'), findsOneWidget);
      expect(tester.widget<TextField>(field('k14.prep')).controller!.text, '5');
      expect(_saveEnabled(tester, 'k14.save'), isTrue);
      expect(find.text('Bật hoặc tắt bán món ở màn Quản lý món.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('K14-ERR saving an empty form shows what is missing under each field and writes nothing', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);
    expect(find.text('Nhập tên món.'), findsNothing);

    await _tap(tester, 'k14.save');

    expect(find.text('Nhập tên món.'), findsOneWidget);
    expect(find.text('Nhập giá món.'), findsOneWidget);
    expect(find.text(MenuItemFormViewModel.invalidMessage), findsOneWidget);
    expect(await menu.watchMenu('q9-t2').first, hasLength(4));

    await _type(tester, 'k14.name', 'Bún bò Huế');
    expect(find.text('Nhập tên món.'), findsNothing);
    expect(find.text('Nhập giá món.'), findsOneWidget);
  });

  testWidgets('K14 the price and the preparation time take digits only', (tester) async {
    await _pump(tester, FakeMenuRepository());

    await _type(tester, 'k14.price', '4a5.0,00');
    await _type(tester, 'k14.prep', '1x2');

    expect(tester.widget<TextField>(field('k14.price')).controller!.text, '45000');
    expect(tester.widget<TextField>(field('k14.prep')).controller!.text, '12');
  });

  testWidgets('K14 adds the item, tells the staff member and returns to the menu', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _type(tester, 'k14.name', 'Bún bò Huế');
    await _tap(tester, 'k14.category.other');
    await _type(tester, 'k14.price', '45000');
    await _type(tester, 'k14.prep', '6');
    await _type(tester, 'k14.description', 'Cay vừa');
    await _tap(tester, 'k14.save');

    expect(find.text('Đã thêm "Bún bò Huế" vào thực đơn.'), findsOneWidget);
    expect(find.text('K08'), findsOneWidget);
    final item = await _item(menu, 'q9-t2-bun-bo-hue');
    expect(
      (item.priceVnd, item.prepMinutes, item.category, item.description),
      (45000, 6, ItemCategory.other, 'Cay vừa'),
    );
  });

  testWidgets('K14 says when the item is already on the menu', (tester) async {
    final menu = FakeMenuRepository();
    await menu.upsertItem(
      const MenuItem(
        id: '',
        name: 'Bún bò Huế',
        priceVnd: 45000,
        category: ItemCategory.food,
        prepMinutes: 6,
        kioskId: 'q9-t2',
      ),
    );
    await _pump(tester, menu);

    await _type(tester, 'k14.name', 'Bún bò Huế');
    await _type(tester, 'k14.price', '40000');
    await _tap(tester, 'k14.save');

    expect(find.text('Món này đã có trong thực đơn.'), findsWidgets);
    expect(find.text('K08'), findsNothing);
    expect(await menu.watchMenu('q9-t2').first, hasLength(5));
  });

  testWidgets('K14 says when saving fails and keeps what was typed', (tester) async {
    await _pump(tester, _OfflineSave());
    await _type(tester, 'k14.name', 'Bún bò Huế');
    await _type(tester, 'k14.price', '45000');

    await _tap(tester, 'k14.save');

    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Bún bò Huế'), findsOneWidget);
    expect(find.text('K08'), findsNothing);
  });

  testWidgets('K15 opens with the item\'s values; saving stays off until something changes', (tester) async {
    await _pump(tester, FakeMenuRepository(), itemId: 'm1');

    expect(find.text('Sửa món'), findsOneWidget);
    expect(tester.widget<TextField>(field('k15.name')).controller!.text, 'Combo Tacos Bò Phô Mai');
    expect(tester.widget<TextField>(field('k15.price')).controller!.text, '39000');
    expect(tester.widget<TextField>(field('k15.prep')).controller!.text, '4');
    expect(find.text('Bật hoặc tắt bán món ở màn Quản lý món.'), findsOneWidget);
    expect(_saveEnabled(tester, 'k15.save'), isFalse);

    await _type(tester, 'k15.price', '42000');
    expect(_saveEnabled(tester, 'k15.save'), isTrue);
  });

  testWidgets('K15 saves the change, tells the staff member and returns to the menu', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu, itemId: 'm1');

    await _type(tester, 'k15.price', '42000');
    await _tap(tester, 'k15.save');

    expect(find.text('Đã lưu thay đổi của "Combo Tacos Bò Phô Mai".'), findsOneWidget);
    expect(find.text('K08'), findsOneWidget);
    expect((await _item(menu, 'm1')).priceVnd, 42000);
  });

  testWidgets('K15 shows the error of a wrong value and does not save it', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu, itemId: 'm1');

    await _type(tester, 'k15.price', '0');
    await _tap(tester, 'k15.save');

    expect(find.text('Giá món phải lớn hơn 0.'), findsOneWidget);
    expect((await _item(menu, 'm1')).priceVnd, 39000);
  });

  testWidgets('K15 of an item of another kiosk, an unknown item or an account without a kiosk explains why', (
    tester,
  ) async {
    await _pump(tester, FakeMenuRepository(), itemId: 'm5');
    expect(byId('k14.empty'), findsOneWidget);
    expect(find.text(MenuItemFormViewModel.notYoursMessage), findsOneWidget);
    await tester.tap(find.text('Về quản lý món'));
    await tester.pumpAndSettle();
    expect(find.text('K08'), findsOneWidget);

    await _pump(tester, FakeMenuRepository(), itemId: 'nope');
    expect(find.text(MenuItemFormViewModel.notFoundMessage), findsOneWidget);

    await _pump(tester, FakeMenuRepository(), kioskId: null);
    expect(find.text(MenuItemFormViewModel.noKioskMessage), findsOneWidget);
  });

  testWidgets('K15 shows the loading state while the item has not arrived', (tester) async {
    await _pump(tester, _NeverLoads(), itemId: 'm1', settle: false);
    expect(find.text('Đang tải món…'), findsOneWidget);
  });

  testWidgets('K15 shows an error with a retry when the item cannot be loaded', (tester) async {
    await _pump(tester, _OfflineGet(), itemId: 'm1');
    expect(byId('k15.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('K14 and K15 back goes to the menu when the form was opened without a history', (tester) async {
    await _pump(tester, FakeMenuRepository());
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('K08'), findsOneWidget);
  });
}
