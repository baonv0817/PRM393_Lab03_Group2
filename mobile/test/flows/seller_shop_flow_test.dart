import 'package:breakbite/app.dart';
import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/ui/seller_shop/view_models/shift_stats_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fake_dependencies.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Future<Kiosk> _kiosk(AppDependencies deps) async =>
    (await deps.menu.watchKiosks().first).firstWhere((Kiosk k) => k.id == 'q9-t2');

void main() {
  testWidgets('a staff member pauses the kiosk in K10, a customer cannot order, and K11 opens from K10', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(412, 2400);
    addTearDown(tester.view.reset);
    final deps = createFakeDependencies(role: UserRole.staff, signedIn: true);
    await tester.pumpWidget(BreakBiteApp(dependencies: deps));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Quán')));
    await tester.pumpAndSettle();
    expect(find.text('Kiosk Q9 · Tầng 2'), findsOneWidget);
    expect((await _kiosk(deps)).acceptsOrders(DateTime.now()), isTrue);

    await tester.tap(byId('k10.pause.30'));
    await tester.pumpAndSettle();
    expect(find.text('Tạm ngưng nhận đơn 30 phút.'), findsOneWidget);
    final paused = await _kiosk(deps);
    expect(paused.acceptsOrders(DateTime.now()), isFalse, reason: 'a customer reads the same kiosk document');
    expect(paused.pausedUntil, isNotNull);

    await tester.tap(byId('k10.resume'));
    await tester.pumpAndSettle();
    expect((await _kiosk(deps)).acceptsOrders(DateTime.now()), isTrue);

    await tester.enterText(find.descendant(of: byId('k10.notice'), matching: find.byType(TextField)), 'Hết sốt');
    await tester.pumpAndSettle();
    await tester.tap(byId('k10.save'));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu thông tin quán.'), findsOneWidget);
    expect((await _kiosk(deps)).notice, 'Hết sốt');

    await tester.tap(byId('k10.stats'));
    await tester.pumpAndSettle();
    expect(find.text('Ca hôm nay'), findsOneWidget);
    // No order was placed today, so the shift is empty; the figures themselves are tested with a fixed clock.
    expect(find.text(ShiftStatsViewModel.emptyMessage), findsOneWidget);
    expect(byId('k11.refresh'), findsOneWidget);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Hết sốt'), findsOneWidget, reason: 'back on K10 with the saved notice');
  });
}
