import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/menu/view_models/alternatives_view_model.dart';
import 'package:breakbite/ui/menu/widgets/alternatives_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

class _FailingMenu extends FakeMenuRepository {
  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) => Stream.error(Exception('offline'));
}

Future<FakeCartRepository> pumpAlternatives(
  WidgetTester tester,
  String id, {
  FakeMenuRepository? menu,
  Size size = TestScreens.narrow,
}) async {
  final cart = FakeCartRepository();
  await pumpScreen(
    tester,
    const AlternativesScreen(),
    size: size,
    providers: [
      ChangeNotifierProvider(
        create: (_) => AlternativesViewModel(
          menu: menu ?? FakeMenuRepository(),
          cart: cart,
          analytics: FakeAnalyticsService(),
          crash: FakeCrashService(),
          uid: 'u1',
          itemId: id,
        ),
      ),
    ],
  );
  return cart;
}

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide]) {
    testWidgets('S22 at ${size.width.round()} dp shows the sold-out item, when it is back and the suggestions', (
      tester,
    ) async {
      await pumpAlternatives(tester, 'm4', size: size);
      expect(find.text('Món tạm hết'), findsOneWidget);
      expect(byId('s22.item.m4'), findsOneWidget);
      expect(find.text('Tacos Gà Giòn Sốt Cay'), findsOneWidget);
      expect(find.text('Tạm hết'), findsOneWidget);
      expect(find.descendant(of: byId('s22.availability'), matching: find.text('Có lại lúc 10:30')), findsOneWidget);
      expect(find.text('Gợi ý thay thế còn hàng'), findsOneWidget);
      expect(byId('s22.alt.m1'), findsOneWidget);
      expect(byId('s22.alt.m2'), findsOneWidget);
      // A drink, an item of another kiosk and the sold-out item itself are not offered as a replacement.
      expect(byId('s22.alt.m3'), findsNothing);
      expect(byId('s22.alt.m5'), findsNothing);
      expect(byId('s22.alt.m4'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S22 the sold-out item has no add button, its suggestions do', (tester) async {
    await pumpAlternatives(tester, 'm4');
    expect(byId('s22.item.m4.add'), findsNothing);
    expect(byId('s22.alt.m1.add'), findsOneWidget);
    expect(byId('s22.alt.m2.add'), findsOneWidget);
  });

  testWidgets('S22 adding a suggestion turns + into a stepper and shows the cart button', (tester) async {
    final cart = await pumpAlternatives(tester, 'm4');
    expect(byId('s22.cart'), findsNothing);
    await tester.tap(byId('s22.alt.m1.add'));
    await tester.pumpAndSettle();
    expect(byId('s22.alt.m1.qty'), findsOneWidget);
    expect(byId('s22.cart'), findsOneWidget);
    await tester.tap(byId('s22.alt.m1.inc'));
    await tester.pumpAndSettle();
    expect(cart.current('u1').items.single.itemId, 'm1');
    expect(cart.current('u1').items.single.quantity, 2);
  });

  testWidgets('S22 with nothing else in stock says so and offers the menu', (tester) async {
    final menu = FakeMenuRepository();
    await menu.setSoldOut('m1', true);
    await menu.setSoldOut('m2', true);
    await pumpAlternatives(tester, 'm4', menu: menu);
    expect(byId('s22.noSuggestions'), findsOneWidget);
    expect(find.text(AlternativesViewModel.noSuggestionsMessage), findsOneWidget);
    expect(find.text('Xem thực đơn'), findsOneWidget);
    expect(byId('s22.alt.m1'), findsNothing);
  });

  testWidgets('S22 when the item comes back the screen says so and lets it be added', (tester) async {
    final menu = FakeMenuRepository();
    await pumpAlternatives(tester, 'm4', menu: menu);
    expect(byId('s22.item.m4.add'), findsNothing);
    await menu.setSoldOut('m4', false);
    await tester.pumpAndSettle();
    expect(find.text('Món đã có lại'), findsOneWidget);
    expect(find.text('Món này đã có lại, bạn có thể đặt ngay.'), findsOneWidget);
    expect(byId('s22.item.m4.add'), findsOneWidget);
  });

  testWidgets('S22 an unknown item offers a way back to the menu', (tester) async {
    await pumpAlternatives(tester, 'nope');
    expect(byId('s22.empty'), findsOneWidget);
    expect(find.text('Không tìm thấy món.'), findsOneWidget);
    expect(find.text('Về thực đơn'), findsOneWidget);
  });

  testWidgets('S22 a menu that cannot load shows the error with a retry button', (tester) async {
    await pumpAlternatives(tester, 'm4', menu: _FailingMenu());
    expect(byId('s22.retry'), findsOneWidget);
    expect(find.text(AlternativesViewModel.loadErrorMessage), findsOneWidget);
  });
}
