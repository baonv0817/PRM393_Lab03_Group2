import '../../../dev/fakes/fakes.dart';
import 'package:breakbite/ui/onboarding/widgets/onboarding_screen.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<AuthViewModel> pumpOnboarding(WidgetTester tester) async {
  final auth = AuthViewModel(FakeAuthService(), FakeAnalyticsService(), FakeCrashService());
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
  testWidgets('chỉ có logo, tên BreakBite, một dòng giới thiệu và các lối vào', (tester) async {
    await pumpOnboarding(tester);
    expect(find.byType(BreakBiteLogo), findsOneWidget);
    expect(find.bySemanticsLabel('BreakBite'), findsOneWidget);
    expect(find.text('Nạp năng lượng nhanh trong 15 phút giải lao'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(find.text('Bắt đầu đặt món'), findsOneWidget);
    expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
    // Đã bỏ các chữ phụ không cần thiết.
    expect(find.textContaining('Không phải xếp hàng'), findsNothing);
    expect(find.text('Chuẩn bị dự kiến 3–5 phút'), findsNothing);
    expect(find.text('Campus Q9 · Tầng 2'), findsNothing);
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
