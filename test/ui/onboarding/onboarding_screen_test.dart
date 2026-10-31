import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/onboarding/widgets/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

Future<AuthViewModel> pumpOnboarding(WidgetTester tester) async {
  final auth = AuthViewModel(
    FakeAuthService(),
    FakeAnalyticsService(),
    FakeCrashService(),
    InMemorySessionRepository(),
  );
  await pumpScreen(
    tester,
    const OnboardingScreen(),
    providers: [ChangeNotifierProvider<AuthViewModel>.value(value: auth)],
  );
  return auth;
}

void main() {
  testWidgets('entry buttons carry stable test ids for ARTEMIS', (tester) async {
    await pumpOnboarding(tester);
    for (final id in ['s01.skip', 's01.start', 's01.signIn']) {
      expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
    }
  });

  testWidgets('shows only the logo, BreakBite name, one tagline and the entry buttons', (tester) async {
    await pumpOnboarding(tester);
    expect(find.byType(BreakBiteLogo), findsOneWidget);
    expect(find.bySemanticsLabel('BreakBite'), findsOneWidget);
    expect(find.text('Nạp năng lượng nhanh trong 15 phút giải lao'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);
    expect(find.text('Bắt đầu đặt món'), findsOneWidget);
    expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
    // Unneeded secondary text has been removed.
    expect(find.textContaining('Không phải xếp hàng'), findsNothing);
    expect(find.text('Chuẩn bị dự kiến 3–5 phút'), findsNothing);
    expect(find.text('Campus Q9 · Tầng 2'), findsNothing);
  });

  for (final label in ['Bỏ qua', 'Bắt đầu đặt món', 'Đăng nhập bằng Google']) {
    testWidgets('tapping "$label" marks Onboarding as seen', (tester) async {
      final auth = await pumpOnboarding(tester);
      expect(auth.onboardingDone, isFalse);
      await tester.tap(find.text(label));
      expect(auth.onboardingDone, isTrue);
    });
  }

  testWidgets('primary button is at least 56 dp tall and spans the full width', (tester) async {
    await pumpOnboarding(tester);
    final size = tester.getSize(find.widgetWithText(FilledButton, 'Bắt đầu đặt món'));
    expect(size.height, greaterThanOrEqualTo(56));
    expect(size.width, greaterThan(300));
  });
}
