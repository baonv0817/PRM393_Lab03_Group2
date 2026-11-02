import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/seller_menu/view_models/seller_menu_view_model.dart';
import 'package:breakbite/ui/seller_menu/widgets/seller_menu_screen.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

class _FailingMenu extends FakeMenuRepository {
  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) => Stream.error(const NetworkException());
}

class _NeverLoads extends FakeMenuRepository {
  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) => const Stream.empty();
}

class _OfflineWrite extends FakeMenuRepository {
  @override
  Future<Result<void>> setSoldOut(String id, bool soldOut, {SoldOutReason? reason, DateTime? availableAgainAt}) async =>
      const Result.error(NetworkException());
}

Future<void> _pump(
  WidgetTester tester,
  FakeMenuRepository menu, {
  String? kioskId = 'q9-t2',
  Size size = TestScreens.narrow,
  bool settle = true,
}) async {
  // The width is the phone's; the height is tall because a ListView only builds what is on screen and
  // the test font is wider than Nunito, so the whole page would otherwise need scrolling.
  await pumpScreen(
    tester,
    const SellerMenuScreen(),
    size: Size(size.width, 3200),
    settle: settle,
    providers: [
      ChangeNotifierProvider(
        create: (_) => SellerMenuViewModel(
          menu: menu,
          crash: FakeCrashService(),
          kioskId: kioskId,
          clock: () => DateTime(2026, 11, 2, 9),
        ),
      ),
    ],
  );
}

Future<void> _tap(WidgetTester tester, String id) async {
  await tester.tap(byId(id));
  await tester.pumpAndSettle();
}

Future<MenuItem> _item(FakeMenuRepository menu, String id) async => (await menu.getItem(id) as Ok<MenuItem>).value;

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide, Size(1024, 768)]) {
    testWidgets('K08 at ${size.width.round()} dp lists the menu by category with a switch per item', (tester) async {
      await _pump(tester, FakeMenuRepository(), size: size);

      expect(find.text('Quản lý món'), findsOneWidget);
      expect(find.text('Kiosk Q9 · Tầng 2'), findsOneWidget);
      expect(find.text('4 món · 1 hết hàng'), findsOneWidget);
      expect(find.text('Món ăn'), findsOneWidget);
      expect(find.text('Đồ uống'), findsOneWidget);
      for (final id in ['m1', 'm2', 'm3', 'm4']) {
        expect(byId('k08.item.$id'), findsOneWidget);
      }
      expect(byId('k08.item.m5'), findsNothing, reason: 'the other kiosk\'s items are not shown');
      expect(find.text('Đang bán'), findsNWidgets(3));
      expect(find.text('Hết hàng · dự kiến có lại lúc 10:30'), findsOneWidget);
      expect(find.text('Đang bán (3)'), findsOneWidget);
      expect(find.text('Hết hàng (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('K09 switching an item off asks why and when it is back, then marks it sold out', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k08.item.m1.switch');
    expect(find.text('Báo hết Combo Tacos Bò Phô Mai'), findsOneWidget);
    for (final reason in SoldOutReason.values) {
      expect(byId('k09.reason.${reason.name}'), findsOneWidget);
    }
    await _tap(tester, 'k09.reason.machineBroken');
    await _tap(tester, 'k09.back.60');
    await _tap(tester, 'k09.confirm');

    expect(find.text('Combo Tacos Bò Phô Mai đã chuyển sang hết hàng.'), findsOneWidget);
    expect(find.text('Máy móc hỏng · dự kiến có lại lúc 10:00'), findsOneWidget);
    expect(find.text('Hết hàng (2)'), findsOneWidget);
    final stored = await _item(menu, 'm1');
    expect((stored.soldOut, stored.soldOutReason), (true, SoldOutReason.machineBroken));
    expect(stored.availableAgainAt, DateTime(2026, 11, 2, 10));
  });

  testWidgets('K09 confirming at once uses "out of ingredients" with no expected time', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k08.item.m2.switch');
    await _tap(tester, 'k09.confirm');

    final stored = await _item(menu, 'm2');
    expect(
      (stored.soldOut, stored.soldOutReason, stored.availableAgainAt),
      (true, SoldOutReason.outOfIngredients, null),
    );
    expect(find.text('Hết nguyên liệu'), findsOneWidget);
  });

  testWidgets('K09 keeping the item as it is changes nothing', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k08.item.m1.switch');
    await _tap(tester, 'k09.cancel');

    expect((await _item(menu, 'm1')).soldOut, isFalse);
    expect(find.text('4 món · 1 hết hàng'), findsOneWidget);
    expect(find.textContaining('đã chuyển sang hết hàng'), findsNothing);
  });

  testWidgets('K08 switching a sold-out item on puts it back on sale at once', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k08.item.m4.switch');

    expect(find.text('Tacos Gà Giòn Sốt Cay đã bán lại.'), findsOneWidget);
    expect(find.text('Đang bán'), findsNWidgets(4));
    expect(find.text('4 món · 0 hết hàng'), findsOneWidget);
    final stored = await _item(menu, 'm4');
    expect((stored.soldOut, stored.availableAgainAt), (false, null));
  });

  testWidgets('K08 filters the list to what is on sale or sold out', (tester) async {
    await _pump(tester, FakeMenuRepository());

    await _tap(tester, 'k08.filter.soldOut');
    expect(byId('k08.item.m4'), findsOneWidget);
    expect(byId('k08.item.m1'), findsNothing);

    await _tap(tester, 'k08.filter.available');
    expect(byId('k08.item.m1'), findsOneWidget);
    expect(byId('k08.item.m4'), findsNothing);

    await _tap(tester, 'k08.filter.all');
    expect(byId('k08.item.m4'), findsOneWidget);
  });

  testWidgets('K08 says when the filter has nothing to show', (tester) async {
    final menu = FakeMenuRepository();
    await menu.setSoldOut('m4', false);
    await _pump(tester, menu);

    await _tap(tester, 'k08.filter.soldOut');
    expect(byId('k08.emptyFilter'), findsOneWidget);
    expect(find.text('Chưa có món nào hết hàng.'), findsOneWidget);
  });

  testWidgets('K08 says when a change cannot be saved and leaves the item on sale', (tester) async {
    final menu = _OfflineWrite();
    await _pump(tester, menu);

    await _tap(tester, 'k08.item.m1.switch');
    await _tap(tester, 'k09.confirm');

    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Đang bán'), findsNWidgets(3));
    expect((await _item(menu, 'm1')).soldOut, isFalse);
  });

  testWidgets('K08 of an account without a kiosk explains why there is no menu', (tester) async {
    await _pump(tester, FakeMenuRepository(), kioskId: null);

    expect(byId('k08.empty'), findsOneWidget);
    expect(find.text(SellerMenuViewModel.noKioskMessage), findsOneWidget);
  });

  testWidgets('K08 shows the empty state for a kiosk without items', (tester) async {
    await _pump(tester, FakeMenuRepository(), kioskId: 'nvh-t1');

    expect(byId('k08.empty'), findsOneWidget);
    expect(find.text(SellerMenuViewModel.emptyMessage), findsOneWidget);
  });

  testWidgets('K08 shows the loading state while the menu has not arrived', (tester) async {
    await _pump(tester, _NeverLoads(), settle: false);
    expect(find.text('Đang tải thực đơn…'), findsOneWidget);
  });

  testWidgets('K08 shows an error with a retry when the menu cannot be loaded', (tester) async {
    await _pump(tester, _FailingMenu());
    expect(byId('k08.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
