import 'package:breakbite/app.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dev/fake_dependencies.dart';

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
    expect(find.text('S03'), findsOneWidget);
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ sinh viên'), findsOneWidget);
    await tester.scrollUntilVisible(find.bySemanticsIdentifier('s15.signOut'), 200);
    expect(find.bySemanticsIdentifier('s15.signOut'), findsOneWidget);
  });

  testWidgets('signed-in seller lands in the seller app with 4 tabs', (tester) async {
    await tester.pumpWidget(BreakBiteApp(dependencies: createFakeDependencies(role: UserRole.staff, signedIn: true)));
    await tester.pumpAndSettle();
    expect(find.text('K02'), findsOneWidget);
    expect(find.text('Quét mã'), findsOneWidget);
  });
}
