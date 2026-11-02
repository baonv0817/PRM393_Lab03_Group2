import 'package:breakbite/app.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fake_dependencies.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

void main() {
  testWidgets('a staff member switches an item off in K08, and the customer menu has it sold out at once', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(412, 1800);
    addTearDown(tester.view.reset);
    final deps = createFakeDependencies(role: UserRole.staff, signedIn: true);
    await tester.pumpWidget(BreakBiteApp(dependencies: deps));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Món')));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý món'), findsOneWidget);
    expect(find.text('Kiosk Q9 · Tầng 2'), findsOneWidget);

    Future<MenuItem> customerSees(String id) async =>
        (await deps.menu.watchMenu('q9-t2').first).firstWhere((i) => i.id == id);
    expect((await customerSees('m1')).soldOut, isFalse);

    await tester.tap(byId('k08.item.m1.switch'));
    await tester.pumpAndSettle();
    await tester.tap(byId('k09.reason.outOfIngredients'));
    await tester.pumpAndSettle();
    await tester.tap(byId('k09.confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Combo Tacos Bò Phô Mai đã chuyển sang hết hàng.'), findsOneWidget);
    final sold = await customerSees('m1');
    expect((sold.soldOut, sold.soldOutReason), (true, SoldOutReason.outOfIngredients));

    await tester.tap(byId('k08.item.m1.switch'));
    await tester.pumpAndSettle();
    expect(find.text('Combo Tacos Bò Phô Mai đã bán lại.'), findsOneWidget);
    expect(((await deps.menu.getItem('m1')) as Ok<MenuItem>).value.soldOut, isFalse);
  });
}
