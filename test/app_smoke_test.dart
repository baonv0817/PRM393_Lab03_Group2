import 'package:breakbite/app.dart';
import 'package:breakbite/dev/dev_services.dart';
import 'package:breakbite/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chưa đăng nhập: thấy Onboarding (S01) trước, bấm Bỏ qua mới sang đăng nhập (S26)', (tester) async {
    await tester.pumpWidget(BreakBiteApp(services: createDevServices()));
    await tester.pumpAndSettle();
    expect(find.text('Nạp năng lượng nhanh trong 15 phút giải lao'), findsOneWidget);
    expect(find.text('S26'), findsNothing);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.text('S26'), findsOneWidget);
    expect(find.text('Nạp năng lượng nhanh trong 15 phút giải lao'), findsNothing);
    expect(find.text('Món nhanh · tối đa 5 phút'), findsNothing);
  });

  testWidgets('đã đăng nhập: Trang chủ có thanh dưới 4 tab, chuyển tab được', (tester) async {
    await tester.pumpWidget(BreakBiteApp(services: createDevServices(signedIn: true)));
    await tester.pumpAndSettle();
    expect(find.text('Món nhanh · tối đa 5 phút'), findsOneWidget); // S02 Trang chủ (màn thật)
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    await tester.tap(find.text('Thực đơn'));
    await tester.pumpAndSettle();
    expect(find.text('S03'), findsOneWidget);
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('S15'), findsOneWidget);
  });

  testWidgets('người bán đăng nhập thì vào app người bán với 4 tab', (tester) async {
    await tester.pumpWidget(BreakBiteApp(services: createDevServices(role: UserRole.staff, signedIn: true)));
    await tester.pumpAndSettle();
    expect(find.text('K02'), findsOneWidget);
    expect(find.text('Quét mã'), findsOneWidget);
  });
}
