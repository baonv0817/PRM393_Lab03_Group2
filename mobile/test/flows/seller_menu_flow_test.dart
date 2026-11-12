import 'package:breakbite/app.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fake_dependencies.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Future<void> _type(WidgetTester tester, String id, String value) async {
  await tester.enterText(find.descendant(of: byId(id), matching: find.byType(TextField)), value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a staff member adds an item in K14 and changes its price in K15, and customers see both', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(412, 2400);
    addTearDown(tester.view.reset);
    final deps = createFakeDependencies(role: UserRole.staff, signedIn: true);
    await tester.pumpWidget(BreakBiteApp(dependencies: deps));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Món')));
    await tester.pumpAndSettle();
    expect(find.text('Món tại quầy'), findsOneWidget);

    await tester.tap(byId('k08.add'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm món mới'), findsOneWidget);
    await tester.tap(byId('k14.save'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên món.'), findsOneWidget);
    await _type(tester, 'k14.name', 'Bún bò Huế');
    await _type(tester, 'k14.price', '45000');
    await tester.tap(byId('k14.save'));
    await tester.pumpAndSettle();

    expect(find.text('Đã thêm "Bún bò Huế" vào thực đơn.'), findsOneWidget);
    expect(byId('k08.item.q9-t2-bun-bo-hue'), findsOneWidget);
    final customerMenu = await deps.menu.watchMenu('q9-t2').first;
    expect(customerMenu.map((i) => i.name), contains('Bún bò Huế'));

    await tester.tap(byId('k08.item.q9-t2-bun-bo-hue.edit'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa món'), findsOneWidget);
    await _type(tester, 'k15.price', '48000');
    await tester.tap(byId('k15.save'));
    await tester.pumpAndSettle();

    expect(find.text('Đã lưu thay đổi của "Bún bò Huế".'), findsOneWidget);
    expect(find.text('48.000đ · Còn hàng'), findsOneWidget);
    final changed = (await deps.menu.getItem('q9-t2-bun-bo-hue')) as Ok<MenuItem>;
    expect(changed.value.priceVnd, 48000);
  });

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
    expect(find.text('Món tại quầy'), findsOneWidget);

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
