import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/ui/menu/view_models/item_detail_view_model.dart';
import 'package:breakbite/ui/menu/view_models/menu_view_model.dart';
import 'package:breakbite/ui/menu/widgets/item_detail_screen.dart';
import 'package:breakbite/ui/menu/widgets/menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Future<FakeCartRepository> pumpMenu(WidgetTester tester, {Size size = TestScreens.narrow}) async {
  final cart = FakeCartRepository();
  await pumpScreen(
    tester,
    const MenuScreen(),
    size: size,
    providers: [
      ChangeNotifierProvider(
        create: (_) => MenuViewModel(
          menu: FakeMenuRepository(),
          cart: cart,
          session: InMemorySessionRepository(),
          analytics: FakeAnalyticsService(),
          crash: FakeCrashService(),
          uid: 'u1',
          clock: () => DateTime(2026, 11, 2, 10),
        ),
      ),
    ],
  );
  return cart;
}

Future<void> pumpDetail(WidgetTester tester, String id, {FakeCartRepository? cart}) => pumpScreen(
  tester,
  const ItemDetailScreen(),
  providers: [
    ChangeNotifierProvider(
      create: (_) => ItemDetailViewModel(
        menu: FakeMenuRepository(),
        cart: cart ?? FakeCartRepository(),
        analytics: FakeAnalyticsService(),
        crash: FakeCrashService(),
        uid: 'u1',
        itemId: id,
      ),
    ),
  ],
);

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S03 at ${size.width.round()} dp shows the kiosk, search, filters and the whole menu', (tester) async {
      await pumpMenu(tester, size: size);
      expect(find.text('Thực đơn'), findsOneWidget);
      expect(find.text('Kiosk Q9 · Tầng 2 · Mở · chờ 5–7 phút'), findsOneWidget);
      expect(byId('s03.search'), findsOneWidget);
      for (final filter in ['quick', 'food', 'drink']) {
        expect(byId('s03.filter.$filter'), findsOneWidget);
      }
      for (final id in ['m1', 'm2', 'm3', 'm4']) {
        await tester.scrollUntilVisible(byId('s03.item.$id'), 120, scrollable: find.byType(Scrollable).last);
        expect(byId('s03.item.$id'), findsOneWidget);
      }
      expect(find.text('Tạm hết'), findsOneWidget);
      expect(find.text('Có lại lúc 10:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S03 search with no match offers to clear the filters', (tester) async {
    await pumpMenu(tester);
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pumpAndSettle();
    expect(byId('s03.empty'), findsOneWidget);
    expect(find.text('Không có món phù hợp'), findsOneWidget);
    await tester.tap(find.text('Xoá bộ lọc'));
    await tester.pumpAndSettle();
    expect(byId('s03.item.m1'), findsOneWidget);
    expect(find.text('pizza'), findsNothing);
  });

  testWidgets('S03 the first + turns into a stepper and shows the cart button', (tester) async {
    final cart = await pumpMenu(tester);
    expect(byId('s03.cart'), findsNothing);
    await tester.tap(byId('s03.item.m1.add'));
    await tester.pumpAndSettle();
    expect(byId('s03.item.m1.qty'), findsOneWidget);
    expect(byId('s03.cart'), findsOneWidget);
    await tester.tap(byId('s03.item.m1.inc'));
    await tester.pumpAndSettle();
    expect(cart.current('u1').items.single.quantity, 2);
  });

  testWidgets('S04 shows the item, a note for the kitchen and a total that follows the quantity', (tester) async {
    await pumpDetail(tester, 'm1');
    expect(find.text('Combo Tacos Bò Phô Mai'), findsOneWidget);
    expect(find.text('4 phút'), findsOneWidget);
    expect(find.text('Ghi chú cho bếp'), findsOneWidget);
    expect(byId('s04.note'), findsOneWidget);
    expect(find.text('Thêm vào giỏ · 39.000đ'), findsOneWidget);
    await tester.tap(byId('s04.quantity.inc'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm vào giỏ · 78.000đ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S04 a sold-out item explains when it is back and cannot be added', (tester) async {
    await pumpDetail(tester, 'm4');
    expect(byId('s04.blocker'), findsOneWidget);
    expect(find.text('Món này đang tạm hết, có lại lúc 10:30.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.descendant(of: byId('s04.add'), matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('S04 an unknown item offers a way back to the menu', (tester) async {
    await pumpDetail(tester, 'nope');
    expect(byId('s04.empty'), findsOneWidget);
    expect(find.text('Về thực đơn'), findsOneWidget);
  });
}
