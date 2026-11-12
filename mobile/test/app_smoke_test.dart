import 'package:breakbite/app.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dev/fake_dependencies.dart';
import '../dev/fakes/fakes.dart';

void main() {
  testWidgets('signed out: shows Onboarding (S01) first, tapping Skip goes to sign-in (S26)', (tester) async {
    await tester.pumpWidget(BreakBiteApp(dependencies: createFakeDependencies()));
    await tester.pumpAndSettle();
    expect(find.text('Nạp năng lượng nhanh trong 15 phút giải lao'), findsOneWidget);
    expect(find.bySemanticsIdentifier('s26.google'), findsNothing);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('s26.google'), findsOneWidget);
    expect(find.text('Nạp năng lượng nhanh trong 15 phút giải lao'), findsNothing);
    expect(find.text('Món nhanh · tối đa 5 phút'), findsNothing);
  });

  testWidgets('signing in from S26 opens Home; signing out from S15 returns to S26', (tester) async {
    await tester.pumpWidget(BreakBiteApp(dependencies: createFakeDependencies()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.bySemanticsIdentifier('s26.google'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsIdentifier('s26.google'));
    await tester.pumpAndSettle();
    expect(find.text('Món nhanh · tối đa 5 phút'), findsOneWidget);

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.bySemanticsIdentifier('s15.signOut'), 200);
    await tester.tap(find.bySemanticsIdentifier('s15.signOut'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('s26.google'), findsOneWidget);
    expect(find.text('Cá nhân'), findsNothing);
  });

  testWidgets('signed in: Home has a 4-tab bottom bar and tabs can be switched', (tester) async {
    await tester.pumpWidget(BreakBiteApp(dependencies: createFakeDependencies(signedIn: true)));
    await tester.pumpAndSettle();
    expect(find.text('Món nhanh · tối đa 5 phút'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    await tester.tap(find.text('Thực đơn'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('s03.search'), findsOneWidget);
    expect(find.bySemanticsIdentifier('s03.item.m1'), findsOneWidget);
    await tester.tap(find.text('Đơn hàng').last);
    await tester.pumpAndSettle();
    expect(find.text('Đang xử lý (0)'), findsOneWidget);
    expect(find.bySemanticsIdentifier('s08.empty'), findsOneWidget);
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ sinh viên'), findsOneWidget);
    await tester.scrollUntilVisible(find.bySemanticsIdentifier('s15.signOut'), 200);
    expect(find.bySemanticsIdentifier('s15.signOut'), findsOneWidget);
  });

  testWidgets('signed-in seller lands in the seller app with 4 tabs', (tester) async {
    await tester.pumpWidget(BreakBiteApp(dependencies: createFakeDependencies(role: UserRole.staff, signedIn: true)));
    await tester.pumpAndSettle();
    expect(find.text('Đơn hôm nay'), findsOneWidget);
    expect(find.text('Quét mã'), findsOneWidget);
  });

  testWidgets('opening the app already signed in: the cart belongs to the user and switching kiosk warns first', (
    tester,
  ) async {
    final deps = createFakeDependencies(signedIn: true);
    final cart = deps.cart as FakeCartRepository;
    await tester.pumpWidget(BreakBiteApp(dependencies: deps));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsIdentifier('s02.item.m1.add'));
    await tester.pumpAndSettle();
    expect(cart.current('dev-user').items, hasLength(1));
    expect(cart.current('').items, isEmpty);
    await tester.tap(find.bySemanticsIdentifier('s02.cart'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('s05.item.m1'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Kiosk Q9 · Tầng 2').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsIdentifier('s27.kiosk.q9-t4'));
    await tester.pump();
    await tester.tap(find.bySemanticsIdentifier('s27.confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Đổi sang Kiosk Q9 · Tầng 4?'), findsOneWidget);
    await tester.tap(find.text('Đổi kiosk'));
    await tester.pumpAndSettle();
    expect(find.text('Kiosk Q9 · Tầng 4'), findsOneWidget);
    expect(cart.current('dev-user').isEmpty, isTrue);
  });
}
