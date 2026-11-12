import 'package:breakbite/ui/seller_menu/view_models/seller_menu_view_model.dart';
import 'package:breakbite/ui/seller_menu/widgets/seller_menu_screen.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
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
    testWidgets('K08 at ${size.width.round()} dp lists the menu as a flat list with a switch per item', (tester) async {
      await _pump(tester, FakeMenuRepository(), size: size);

      expect(find.text('Món tại quầy'), findsOneWidget);
      expect(byId('k08.add'), findsOneWidget, reason: 'the add button is in the top bar, as in Figma');
      expect(find.text('Món ăn'), findsNothing, reason: 'the list is flat, without category headings');
      for (final id in ['m1', 'm2', 'm3', 'm4']) {
        expect(byId('k08.item.$id'), findsOneWidget);
      }
      expect(byId('k08.item.m5'), findsNothing, reason: 'the other kiosk\'s items are not shown');
      expect(find.text('39.000đ · Còn hàng'), findsOneWidget);
      expect(find.text('35.000đ · Hết · có lại 10:30'), findsOneWidget);
      expect(find.textContaining('Còn hàng'), findsNWidgets(3));
      double top(String id) => tester.getTopLeft(byId('k08.item.$id')).dy;
      final ids = ['m1', 'm2', 'm3', 'm4']..sort((x, y) => top(x).compareTo(top(y)));
      expect(ids, ['m1', 'm2', 'm4', 'm3'], reason: 'food first, then drinks, each by name');
      for (final label in ['Tất cả', 'Đang bán', 'Hết']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('K09 switching an item off asks why and when it is back, then marks it sold out', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k08.item.m1.switch');
    expect(find.text('Đánh dấu hết món'), findsOneWidget);
    expect(find.text('Combo Tacos Bò Phô Mai'), findsNWidgets(2), reason: 'the row and the sheet');
    for (final reason in SoldOutReason.values) {
      expect(byId('k09.reason.${reason.name}'), findsOneWidget);
    }
    // At 9:00 the choices are the next two half hours and "Hết ngày"; the first is selected.
    for (final id in ['k09.back.0930', 'k09.back.1000', 'k09.back.endOfDay']) {
      expect(byId(id), findsOneWidget, reason: id);
    }
    await _tap(tester, 'k09.reason.machineBroken');
    await _tap(tester, 'k09.back.1000');
    await _tap(tester, 'k09.confirm');

    expect(find.text('Combo Tacos Bò Phô Mai đã chuyển sang hết hàng.'), findsOneWidget);
    expect(find.text('39.000đ · Hết · có lại 10:00'), findsOneWidget);
    final stored = await _item(menu, 'm1');
    expect((stored.soldOut, stored.soldOutReason), (true, SoldOutReason.machineBroken));
    expect(stored.availableAgainAt, DateTime(2026, 11, 2, 10));
  });

  testWidgets('K09 confirming at once uses "out of ingredients" and the first time offered', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k08.item.m2.switch');
    await _tap(tester, 'k09.confirm');

    final stored = await _item(menu, 'm2');
    expect(
      (stored.soldOut, stored.soldOutReason, stored.availableAgainAt),
      (true, SoldOutReason.outOfIngredients, DateTime(2026, 11, 2, 9, 30)),
    );
    expect(find.text('35.000đ · Hết · có lại 09:30'), findsOneWidget);
  });

  testWidgets('K09 "Hết ngày" stores no expected time', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k08.item.m2.switch');
    await _tap(tester, 'k09.back.endOfDay');
    await _tap(tester, 'k09.confirm');

    expect((await _item(menu, 'm2')).availableAgainAt, isNull);
    expect(find.text('35.000đ · Hết'), findsOneWidget);
  });

  testWidgets('K09 keeping the item as it is changes nothing', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k08.item.m1.switch');
    await _tap(tester, 'k09.cancel');

    expect((await _item(menu, 'm1')).soldOut, isFalse);
    expect(find.textContaining('Hết ·'), findsOneWidget, reason: 'only the item that was already sold out');
    expect(find.textContaining('đã chuyển sang hết hàng'), findsNothing);
  });

  testWidgets('K08 switching a sold-out item on puts it back on sale at once', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k08.item.m4.switch');

    expect(find.text('Tacos Gà Giòn Sốt Cay đã bán lại.'), findsOneWidget);
    expect(find.textContaining('Còn hàng'), findsNWidgets(4));
    expect(find.textContaining('Hết ·'), findsNothing);
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
    expect(find.textContaining('Còn hàng'), findsNWidgets(3));
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
