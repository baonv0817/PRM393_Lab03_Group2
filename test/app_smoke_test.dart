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
    expect(find.text('S26'), findsNothing);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.text('S26'), findsOneWidget);
    expect(find.text('Nạp năng lượng nhanh trong 15 phút giải lao'), findsNothing);
    expect(find.text('Món nhanh · tối đa 5 phút'), findsNothing);
  });

  testWidgets('signed in: Home has a 4-tab bottom bar and tabs can be switched', (tester) async {
    await tester.pumpWidget(BreakBiteApp(dependencies: createFakeDependencies(signedIn: true)));
    await tester.pumpAndSettle();
    expect(find.text('Món nhanh · tối đa 5 phút'), findsOneWidget); // S02 Home (real screen)
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    await tester.tap(find.text('Thực đơn'));
    await tester.pumpAndSettle();
    expect(find.text('S03'), findsOneWidget);
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('S15'), findsOneWidget);
  });

  testWidgets('signed-in seller lands in the seller app with 4 tabs', (tester) async {
    await tester.pumpWidget(BreakBiteApp(dependencies: createFakeDependencies(role: UserRole.staff, signedIn: true)));
    await tester.pumpAndSettle();
    expect(find.text('K02'), findsOneWidget);
    expect(find.text('Quét mã'), findsOneWidget);
  });
}
