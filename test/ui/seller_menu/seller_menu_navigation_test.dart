import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/seller_menu/view_models/seller_menu_view_model.dart';
import 'package:breakbite/ui/seller_menu/widgets/seller_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Future<void> _pump(WidgetTester tester, FakeMenuRepository menu, {String? kioskId = 'q9-t2'}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 3200);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: AppRoutes.sellerMenu,
    routes: [
      GoRoute(
        path: AppRoutes.sellerMenu,
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => SellerMenuViewModel(menu: menu, crash: FakeCrashService(), kioskId: kioskId),
          child: const SellerMenuScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.sellerMenuNew,
        builder: (context, state) => const Scaffold(body: Text('K14')),
      ),
      GoRoute(
        path: AppRoutes.sellerMenuEdit,
        builder: (context, state) => Scaffold(body: Text('K15 ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(theme: AppTheme.light(), routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('K08 "Thêm món" opens the form for a new item', (tester) async {
    await _pump(tester, FakeMenuRepository());

    expect(byId('k08.add'), findsOneWidget);
    await tester.tap(byId('k08.add'));
    await tester.pumpAndSettle();
    expect(find.text('K14'), findsOneWidget);
  });

  testWidgets('K08 the edit button of an item opens the form for that item', (tester) async {
    await _pump(tester, FakeMenuRepository());

    expect(find.byTooltip('Sửa Combo Tacos Bò Phô Mai'), findsOneWidget);
    await tester.tap(byId('k08.item.m1.edit'));
    await tester.pumpAndSettle();
    expect(find.text('K15 m1'), findsOneWidget);
  });

  testWidgets('K08 of a kiosk with no items invites adding the first one, without the floating button', (tester) async {
    await _pump(tester, FakeMenuRepository(), kioskId: 'nvh-t1');

    expect(byId('k08.add'), findsNothing);
    expect(find.text('Thêm món đầu tiên'), findsOneWidget);
    await tester.tap(find.text('Thêm món đầu tiên'));
    await tester.pumpAndSettle();
    expect(find.text('K14'), findsOneWidget);
  });

  testWidgets('K08 of an account without a kiosk offers no way to add an item', (tester) async {
    await _pump(tester, FakeMenuRepository(), kioskId: null);

    expect(byId('k08.add'), findsNothing);
    expect(find.text('Thêm món đầu tiên'), findsNothing);
    expect(find.text(SellerMenuViewModel.noKioskMessage), findsOneWidget);
  });

  testWidgets('K08 at 360 dp keeps the edit button and the switch of every row in view', (tester) async {
    await pumpScreen(
      tester,
      const SellerMenuScreen(),
      size: const Size(360, 3200),
      providers: [
        ChangeNotifierProvider(
          create: (_) => SellerMenuViewModel(menu: FakeMenuRepository(), crash: FakeCrashService(), kioskId: 'q9-t2'),
        ),
      ],
    );

    expect(byId('k08.item.m4.edit'), findsOneWidget);
    expect(byId('k08.item.m4.switch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
