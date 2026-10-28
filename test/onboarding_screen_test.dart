import 'package:breakbite/dev/dev_services.dart';
import 'package:breakbite/screens/onboarding_screen.dart';
import 'package:breakbite/theme/app_theme.dart';
import 'package:breakbite/viewmodels/auth_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<AuthViewModel> pumpOnboarding(WidgetTester tester) async {
  final auth = AuthViewModel(DevAuthService(), DevAnalyticsService(), DevCrashService());
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthViewModel>.value(
      value: auth,
      child: MaterialApp(theme: AppTheme.light(), home: const OnboardingScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('hiện đủ nội dung theo Figma S01', (tester) async {
    await pumpOnboarding(tester);
    expect(find.text('Campus Q9 · Tầng 2'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(find.text('Nạp năng lượng nhanh trong 15 phút giải lao'), findsOneWidget);
    expect(find.textContaining('Không phải xếp hàng'), findsOneWidget);
    expect(find.text('Chuẩn bị dự kiến 3–5 phút'), findsOneWidget);
    expect(find.text('Đặt trước, quét mã nhận món'), findsOneWidget);
    expect(find.text('Trả bằng ví hoặc tiền mặt'), findsOneWidget);
    expect(find.text('Bắt đầu đặt món'), findsOneWidget);
    expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
  });

  for (final label in ['Bỏ qua', 'Bắt đầu đặt món', 'Đăng nhập bằng Google']) {
    testWidgets('bấm "$label" đánh dấu đã xem Onboarding', (tester) async {
      final auth = await pumpOnboarding(tester);
      expect(auth.onboardingDone, isFalse);
      await tester.tap(find.text(label));
      expect(auth.onboardingDone, isTrue);
    });
  }

  testWidgets('nút chính cao ≥ 56 dp và rộng hết lề', (tester) async {
    await pumpOnboarding(tester);
    final size = tester.getSize(find.widgetWithText(FilledButton, 'Bắt đầu đặt món'));
    expect(size.height, greaterThanOrEqualTo(56));
    expect(size.width, greaterThan(300));
  });
}
