import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/seller_shop/view_models/shop_view_model.dart';
import 'package:breakbite/ui/seller_shop/widgets/shop_screen.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Finder field(String id) => find.descendant(of: byId(id), matching: find.byType(TextField));

class _OfflineWrite extends FakeMenuRepository {
  @override
  Future<Result<void>> updateKiosk(String id, KioskSettings settings) async => const Result.error(NetworkException());
}

class _FailingKiosks extends FakeMenuRepository {
  @override
  Stream<List<Kiosk>> watchKiosks() => Stream.error(const NetworkException());
}

class _NeverLoads extends FakeMenuRepository {
  @override
  Stream<List<Kiosk>> watchKiosks() => const Stream.empty();
}

Future<void> _pump(
  WidgetTester tester,
  FakeMenuRepository menu, {
  String? kioskId = 'q9-t2',
  Size size = TestScreens.narrow,
  bool settle = true,
  AuthViewModel? auth,
}) async {
  // The width is the phone's; the height is tall because a ListView only builds what is on screen and
  // the test font is wider than Nunito, so the whole page would otherwise need scrolling.
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(size.width, 3200);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: AppRoutes.sellerShop,
    routes: [
      GoRoute(
        path: AppRoutes.sellerShop,
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => ShopViewModel(
            menu: menu,
            crash: FakeCrashService(),
            kioskId: kioskId,
            clock: () => DateTime(2026, 11, 2, 9),
          ),
          child: const ShopScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.sellerStats,
        builder: (context, state) => const Scaffold(body: Text('K11')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final app = MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
  await tester.pumpWidget(auth == null ? app : ChangeNotifierProvider<AuthViewModel>.value(value: auth, child: app));
  if (settle) await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String id) async {
  await tester.tap(byId(id));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String id, String value) async {
  await tester.enterText(field(id), value);
  await tester.pumpAndSettle();
}

Future<Kiosk> _kiosk(FakeMenuRepository menu) async =>
    (await menu.watchKiosks().first).firstWhere((k) => k.id == 'q9-t2');

void main() {
  for (final size in const [TestScreens.narrow, TestScreens.wide, Size(1024, 768)]) {
    testWidgets('K10 at ${size.width.round()} dp shows the status, the controls and the form', (tester) async {
      await _pump(tester, FakeMenuRepository(), size: size);

      expect(find.text('Quán'), findsOneWidget);
      expect(find.text('Kiosk Q9 · Tầng 2'), findsOneWidget);
      expect(find.text('Mở · chờ 5–7 phút'), findsOneWidget);
      expect(find.text('Đang nhận đơn'), findsOneWidget);
      for (final id in ['k10.open', 'k10.pause.15', 'k10.pause.30', 'k10.pause.60', 'k10.wait.dec', 'k10.wait.inc']) {
        expect(byId(id), findsOneWidget, reason: id);
      }
      for (final id in ['k10.notice', 'k10.openTime', 'k10.closeTime', 'k10.maxOrders', 'k10.stats']) {
        expect(byId(id), findsOneWidget, reason: id);
      }
      expect(byId('k10.resume'), findsNothing, reason: 'there is no pause to end');
      expect(byId('k10.save'), findsNothing, reason: 'nothing was changed');
      expect(find.text('6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('K10 the switch closes the kiosk at once and a customer sees it closed', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k10.open');

    expect(find.text('Quán đã đóng, khách không đặt được nữa.'), findsOneWidget);
    expect(find.text('Đang đóng cửa'), findsOneWidget);
    expect((await _kiosk(menu)).open, isFalse);

    await _tap(tester, 'k10.open');
    expect(find.text('Quán đã mở nhận đơn.'), findsOneWidget);
    expect((await _kiosk(menu)).open, isTrue);
  });

  testWidgets('K10 a pause shows when orders resume and can be ended at once', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k10.pause.30');

    expect(find.text('Tạm ngưng nhận đơn 30 phút.'), findsOneWidget);
    expect(find.text('Tạm ngưng · nhận đơn lại lúc 09:30'), findsOneWidget);
    expect((await _kiosk(menu)).pausedUntil, DateTime(2026, 11, 2, 9, 30));

    await _tap(tester, 'k10.resume');

    expect(find.text('Quán nhận đơn lại.'), findsOneWidget);
    expect(find.text('Mở · chờ 5–7 phút'), findsOneWidget);
    expect(byId('k10.resume'), findsNothing);
    expect((await _kiosk(menu)).pausedUntil, isNull);
  });

  testWidgets('K10 the pause of an hour is named in hours', (tester) async {
    await _pump(tester, FakeMenuRepository());

    await _tap(tester, 'k10.pause.60');

    expect(find.text('Tạm ngưng nhận đơn 1 giờ.'), findsOneWidget);
  });

  testWidgets('K10 the stepper changes the wait a minute at a time and stops at 0', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _tap(tester, 'k10.wait.inc');
    expect(find.text('7'), findsOneWidget);
    expect((await _kiosk(menu)).waitMinutes, 7);
    expect(find.text('Mở · chờ 6–8 phút'), findsOneWidget);

    for (var i = 0; i < 7; i++) {
      await _tap(tester, 'k10.wait.dec');
    }
    expect((await _kiosk(menu)).waitMinutes, 0);
    expect(find.text('0'), findsOneWidget);
    final dec = tester.widget<IconButton>(find.descendant(of: byId('k10.wait.dec'), matching: find.byType(IconButton)));
    expect(dec.onPressed, isNull);
  });

  testWidgets('K10 the save button appears when the form changes and saves the notice, hours and capacity', (
    tester,
  ) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);
    expect(byId('k10.save'), findsNothing);

    await _type(tester, 'k10.notice', 'Hôm nay hết sốt phô mai');
    await _type(tester, 'k10.openTime', '06:30');
    await _type(tester, 'k10.closeTime', '17:00');
    await _type(tester, 'k10.maxOrders', '8');
    expect(byId('k10.save'), findsOneWidget);
    await _tap(tester, 'k10.save');

    expect(find.text('Đã lưu thông tin quán.'), findsOneWidget);
    final kiosk = await _kiosk(menu);
    expect(
      (kiosk.notice, kiosk.openTime, kiosk.closeTime, kiosk.maxOrdersPerSlot),
      ('Hôm nay hết sốt phô mai', '06:30', '17:00', 8),
    );
    expect(byId('k10.save'), findsNothing, reason: 'saved, so nothing is left to save');
  });

  testWidgets('K10 the form shows what the kiosk already has', (tester) async {
    final menu = FakeMenuRepository();
    await menu.updateKiosk(
      'q9-t2',
      const KioskSettings(
        open: true,
        waitMinutes: 6,
        notice: 'Hết sốt',
        openTime: '06:30',
        closeTime: '17:00',
        maxOrdersPerSlot: 5,
      ),
    );
    await _pump(tester, menu);

    String typed(String id) => tester.widget<TextField>(field(id)).controller!.text;
    expect(['k10.notice', 'k10.openTime', 'k10.closeTime', 'k10.maxOrders'].map(typed), [
      'Hết sốt',
      '06:30',
      '17:00',
      '5',
    ]);
    expect(byId('k10.save'), findsNothing, reason: 'the form starts as the kiosk is');
  });

  testWidgets('K10 shows the errors under the fields once a save was tried, and writes nothing', (tester) async {
    final menu = FakeMenuRepository();
    await _pump(tester, menu);

    await _type(tester, 'k10.openTime', '25:00');
    await _type(tester, 'k10.maxOrders', '0');
    expect(find.text('Nhập giờ dạng 06:30.'), findsNothing, reason: 'the errors wait for the first save');
    await _tap(tester, 'k10.save');

    expect(find.text('Nhập giờ dạng 06:30.'), findsOneWidget);
    expect(find.textContaining('Nhập số từ 1 đến'), findsOneWidget);
    expect(find.text(ShopViewModel.invalidMessage), findsOneWidget);
    expect((await _kiosk(menu)).openTime, isNull);
  });

  testWidgets('K10 says so and keeps the form when a write fails', (tester) async {
    final menu = _OfflineWrite();
    await _pump(tester, menu);

    await _tap(tester, 'k10.open');
    expect(find.text(const NetworkException().message), findsOneWidget);
    expect((await _kiosk(menu)).open, isTrue);

    await _type(tester, 'k10.notice', 'Hết sốt');
    await _tap(tester, 'k10.save');
    expect(find.text(const NetworkException().message), findsWidgets);
    expect(find.text('Hết sốt'), findsOneWidget);
    expect(byId('k10.save'), findsOneWidget, reason: 'still unsaved');
  });

  testWidgets('K10 the link opens the shift statistics', (tester) async {
    await _pump(tester, FakeMenuRepository());

    await _tap(tester, 'k10.stats');

    expect(find.text('K11'), findsOneWidget);
  });

  testWidgets('K10 shows a loading state, an error with retry, and a message for an account without a kiosk', (
    tester,
  ) async {
    await _pump(tester, _NeverLoads(), settle: false);
    await tester.pump();
    expect(find.text('Đang tải thông tin quán…'), findsOneWidget);

    await _pump(tester, _FailingKiosks());
    expect(byId('k10.retry'), findsOneWidget);
    expect(find.text(const NetworkException().message), findsOneWidget);

    await _pump(tester, FakeMenuRepository(), kioskId: null);
    expect(byId('k10.empty'), findsOneWidget);
    expect(find.text(ShopViewModel.noKioskMessage), findsOneWidget);
    expect(byId('k10.open'), findsNothing);
  });

  testWidgets('[exploratory] the opening and closing time share a row, and stack at twice the text size', (
    tester,
  ) async {
    await _pump(tester, FakeMenuRepository());
    expect(tester.getTopLeft(field('k10.openTime')).dy, tester.getTopLeft(field('k10.closeTime')).dy);

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();

    final open = tester.getRect(field('k10.openTime'));
    final close = tester.getRect(field('k10.closeTime'));
    expect(close.top, greaterThan(open.bottom), reason: 'one under the other, so each label has the full width');
    expect(close.left, open.left);
    expect(open.width, greaterThan(tester.getSize(find.byType(Scaffold)).width / 2));
  });

  testWidgets('K10 signs the staff member out after a confirmation that says what it costs', (tester) async {
    final service = FakeAuthService(signedIn: true);
    final auth = AuthViewModel(
      service,
      FakeAnalyticsService(),
      FakeCrashService(),
      InMemorySessionRepository(),
      FakeMessagingService(),
    );
    addTearDown(auth.dispose);
    await tester.runAsync(pumpEventQueue);
    await _pump(tester, FakeMenuRepository(), auth: auth);

    await _tap(tester, 'k10.signOut');
    await tester.pumpAndSettle();
    expect(find.text('Đăng xuất?'), findsOneWidget);
    expect(find.text(signOutMessage), findsOneWidget);

    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(auth.user, isNotNull, reason: 'keeping the session signs nobody out');

    await _tap(tester, 'k10.signOut');
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Đăng xuất')));
    await tester.pumpAndSettle();
    expect(auth.user, isNull);
  });
}
