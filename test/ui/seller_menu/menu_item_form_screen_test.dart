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

/// The number the preparation-time stepper shows.
String qty(String id) =>
    (find.descendant(of: byId('$id.qty'), matching: find.byType(Text)).evaluate().first.widget as Text).data!;

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
          create: (_) => MenuItemFormViewModel(
            menu: menu,
            storage: FakeStorageService(),
            photos: FakePhotoPickerService(),
            crash: FakeCrashService(),
            kioskId: kioskId,
          ),
          child: const MenuItemFormScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.sellerMenuEdit,
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => MenuItemFormViewModel(
            menu: menu,
            storage: FakeStorageService(),
            photos: FakePhotoPickerService(),
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
      for (final id in ['name', 'price', 'prep.dec', 'prep.inc', 'inStock', 'description']) {
        expect(byId('k14.$id'), findsOneWidget, reason: id);
      }
      for (final category in ItemCategory.values) {
        expect(byId('k14.category.${category.name}'), findsOneWidget);
      }
      expect(find.text('Tên món'), findsOneWidget);
      expect(find.text('Giá (đ)'), findsOneWidget);
      expect(find.text('Danh mục'), findsOneWidget);
      expect(find.text('Thời gian chuẩn bị'), findsOneWidget);
      expect(find.text('Còn hàng'), findsOneWidget);
      expect(find.text('Lưu món'), findsOneWidget);
      expect(qty('k14.prep'), '5');
      expect(
        tester.widget<Switch>(find.descendant(of: byId('k14.inStock'), matching: find.byType(Switch))).value,
        isTrue,
      );
      expect(_saveEnabled(tester, 'k14.save'), isTrue);
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

  testWidgets('K14 the photo box: empty, a photo is chosen and shown, it can be taken off again', (tester) async {
    await _pump(tester, FakeMenuRepository());
    expect(find.text('Thêm ảnh món (tuỳ chọn)'), findsOneWidget);
    expect(byId('k14.photo.gallery'), findsOneWidget);
    expect(byId('k14.photo.camera'), findsOneWidget);
    expect(byId('k14.photo.remove'), findsNothing, reason: 'nothing to take off yet');

    await _tap(tester, 'k14.photo.gallery');
    expect(find.byType(Image), findsWidgets);
    expect(find.text('Thêm ảnh món (tuỳ chọn)'), findsNothing);
    expect(byId('k14.photo.remove'), findsOneWidget);

    await _tap(tester, 'k14.photo.remove');
    expect(find.text('Thêm ảnh món (tuỳ chọn)'), findsOneWidget);
    expect(byId('k14.photo.remove'), findsNothing);
  });

  testWidgets('K15 opens with the photo the item has and offers to take it off', (tester) async {
    await _pump(tester, FakeMenuRepository(), itemId: 'm1');
    expect(find.text('Thêm ảnh món (tuỳ chọn)'), findsNothing);
    expect(byId('k15.photo.remove'), findsOneWidget);
  });

  testWidgets('K14 the price takes digits only', (tester) async {
    await _pump(tester, FakeMenuRepository());

    await _type(tester, 'k14.price', '4a5.0,00');

    expect(tester.widget<TextField>(field('k14.price')).controller!.text, '45000');
  });

  testWidgets('K14 the stepper changes the preparation time a minute at a time and stops at 0 and 120', (tester) async {
    await _pump(tester, FakeMenuRepository());

    await _tap(tester, 'k14.prep.inc');
    expect(qty('k14.prep'), '6');
    for (var i = 0; i < 7; i++) {
      await _tap(tester, 'k14.prep.dec');
    }
    expect(qty('k14.prep'), '0');
    final dec = tester.widget<IconButton>(find.descendant(of: byId('k14.prep.dec'), matching: find.byType(IconButton)));
    expect(dec.onPressed, isNull);
    for (var i = 0; i < 125; i++) {
      await tester.tap(byId('k14.prep.inc'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(qty('k14.prep'), '120');
    final inc = tester.widget<InkResponse>(
      find.descendant(of: byId('k14.prep.inc'), matching: find.byType(InkResponse)),
    );
    expect(inc.onTap, isNull);
  });

  testWidgets('K14 an item added with "Còn hàng" off starts sold out', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _type(tester, 'k14.name', 'Bún bò Huế');
    await _type(tester, 'k14.price', '45000');
    await _tap(tester, 'k14.inStock');
    await _tap(tester, 'k14.save');

    expect((await _item(menu, 'q9-t2-bun-bo-hue')).soldOut, isTrue);
  });

  testWidgets('K14 adds the item, tells the staff member and returns to the menu', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _type(tester, 'k14.name', 'Bún bò Huế');
    await _tap(tester, 'k14.category.other');
    await _type(tester, 'k14.price', '45000');
    await _tap(tester, 'k14.prep.inc');
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
    expect(qty('k15.prep'), '4');
    expect(
      tester.widget<Switch>(find.descendant(of: byId('k15.inStock'), matching: find.byType(Switch))).value,
      isTrue,
    );
    expect(find.text('Xoá món'), findsNothing, reason: 'items are not deleted; a sold-out item is switched off');
    expect(_saveEnabled(tester, 'k15.save'), isFalse);

    await _type(tester, 'k15.price', '42000');
    expect(_saveEnabled(tester, 'k15.save'), isTrue);
  });

  testWidgets('K15 shows a sold-out item with "Còn hàng" off, and switching it on puts it back on sale', (
    tester,
  ) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu, itemId: 'm4');

    expect(
      tester.widget<Switch>(find.descendant(of: byId('k15.inStock'), matching: find.byType(Switch))).value,
      isFalse,
    );
    expect(_saveEnabled(tester, 'k15.save'), isFalse);

    await _tap(tester, 'k15.inStock');
    expect(_saveEnabled(tester, 'k15.save'), isTrue);
    await _tap(tester, 'k15.save');

    final stored = await _item(menu, 'm4');
    expect((stored.soldOut, stored.soldOutReason, stored.availableAgainAt), (false, null, null));
  });

  testWidgets('K15 switching "Còn hàng" off sets the item sold out; leaving it alone keeps a sold-out reason', (
    tester,
  ) async {
    final menu = FakeMenuRepository();
    await menu.setSoldOut('m4', true, reason: SoldOutReason.machineBroken, availableAgainAt: DateTime(2026, 11, 2, 11));
    await _pump(tester, menu, itemId: 'm4');
    await _type(tester, 'k15.price', '36000');
    await _tap(tester, 'k15.save');

    final kept = await _item(menu, 'm4');
    expect((kept.priceVnd, kept.soldOut, kept.soldOutReason), (36000, true, SoldOutReason.machineBroken));
    expect(kept.availableAgainAt, DateTime(2026, 11, 2, 11));

    await _pump(tester, menu, itemId: 'm1');
    await _tap(tester, 'k15.inStock');
    await _tap(tester, 'k15.save');
    expect((await _item(menu, 'm1')).soldOut, isTrue);
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

  testWidgets('K14 closes with the X and K15 goes back with the arrow, both to the menu', (tester) async {
    await _pump(tester, FakeMenuRepository());
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('K08'), findsOneWidget);

    await _pump(tester, FakeMenuRepository(), itemId: 'm1');
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('K08'), findsOneWidget);
  });
}
