import 'dart:async';

import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/auth/widgets/sign_in_screen.dart';
import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

class _ScriptedAuth extends FakeAuthService {
  _ScriptedAuth(this.outcome);

  final Future<Result<AppUser>> Function() outcome;

  @override
  Future<Result<AppUser>> signInWithGoogle() => outcome();
}

Future<AuthViewModel> pumpSignIn(WidgetTester tester, FakeAuthService auth, {Size size = TestScreens.narrow}) async {
  final vm = AuthViewModel(
    auth,
    FakeAnalyticsService(),
    FakeCrashService(),
    InMemorySessionRepository(),
    FakeMessagingService(),
  );
  addTearDown(vm.dispose);
  await pumpScreen(
    tester,
    const SignInScreen(),
    providers: [ChangeNotifierProvider<AuthViewModel>.value(value: vm)],
    size: size,
  );
  return vm;
}

void main() {
  testWidgets('shows the Google sign-in button with a stable test id and no error at first', (tester) async {
    await pumpSignIn(tester, FakeAuthService());
    expect(find.text('Đăng nhập bằng Google'), findsWidgets);
    expect(find.bySemanticsIdentifier('s26.google'), findsOneWidget);
    expect(find.bySemanticsIdentifier('s26.error'), findsNothing);
  });

  testWidgets('tapping the button signs in', (tester) async {
    final vm = await pumpSignIn(tester, FakeAuthService());
    await tester.tap(find.bySemanticsIdentifier('s26.google'));
    await tester.pumpAndSettle();
    expect(vm.user?.uid, 'dev-user');
  });

  testWidgets('the button shows progress and ignores taps while signing in', (tester) async {
    final pending = Completer<Result<AppUser>>();
    var calls = 0;
    await pumpSignIn(
      tester,
      _ScriptedAuth(() {
        calls++;
        return pending.future;
      }),
    );
    await tester.tap(find.bySemanticsIdentifier('s26.google'));
    await tester.pump();
    expect(find.text('Đang đăng nhập…'), findsOneWidget);
    await tester.tap(find.bySemanticsIdentifier('s26.google'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    pending.complete(const Result.error(CancelledException()));
    await tester.pumpAndSettle();
  });

  testWidgets('a cancelled sign-in shows a message instead of leaving the user stuck', (tester) async {
    await pumpSignIn(tester, _ScriptedAuth(() async => const Result.error(CancelledException())));
    await tester.tap(find.bySemanticsIdentifier('s26.google'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('s26.error'), findsOneWidget);
    expect(find.textContaining('huỷ đăng nhập'), findsOneWidget);
  });

  testWidgets('no network shows the network message and the button stays usable', (tester) async {
    await pumpSignIn(tester, _ScriptedAuth(() async => const Result.error(NetworkException())), size: TestScreens.wide);
    await tester.tap(find.bySemanticsIdentifier('s26.google'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.descendant(of: find.bySemanticsIdentifier('s26.google'), matching: find.byType(OutlinedButton)),
    );
    expect(button.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  group('email and password', () {
    Finder field(String id) => find.descendant(of: find.bySemanticsIdentifier(id), matching: find.byType(TextField));

    testWidgets('shows the email form next to the Google button', (tester) async {
      await pumpSignIn(tester, FakeAuthService());
      expect(find.bySemanticsIdentifier('s26.email'), findsOneWidget);
      expect(find.bySemanticsIdentifier('s26.password'), findsOneWidget);
      expect(find.bySemanticsIdentifier('s26.name'), findsNothing, reason: 'the name is only asked when registering');
      expect(find.bySemanticsIdentifier('s26.google'), findsOneWidget);
    });

    testWidgets('an empty or wrong form shows the problems and sends nothing', (tester) async {
      final vm = await pumpSignIn(tester, FakeAuthService());
      await tester.tap(find.bySemanticsIdentifier('s26.submit'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập email.'), findsOneWidget);
      expect(find.text('Nhập mật khẩu.'), findsOneWidget);
      expect(vm.user, isNull);
    });

    testWidgets('registers an account with a name, then the same email cannot register again', (tester) async {
      final auth = FakeAuthService();
      final vm = await pumpSignIn(tester, auth);
      await tester.tap(find.bySemanticsIdentifier('s26.mode'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('s26.name'), findsOneWidget);

      await tester.enterText(field('s26.name'), 'Minh Quân');
      await tester.enterText(field('s26.email'), 'quan@fpt.edu.vn');
      await tester.enterText(field('s26.password'), 'abc');
      await tester.tap(find.bySemanticsIdentifier('s26.submit'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ít nhất 8'), findsWidgets);
      expect(vm.user, isNull);

      await tester.enterText(field('s26.password'), 'breakbite1');
      await tester.tap(find.bySemanticsIdentifier('s26.submit'));
      await tester.pumpAndSettle();
      expect(vm.user?.displayName, 'Minh Quân');
      expect(vm.user?.email, 'quan@fpt.edu.vn');

      await auth.signOut();
      final again = await vm.register.execute((name: 'Khác', email: 'QUAN@fpt.edu.vn', password: 'breakbite1'));
      expect(again, isA<Err<AppUser>>());
      expect(vm.message, contains('đã có tài khoản'));
    });

    testWidgets('signs in with the right password and says "email hoặc mật khẩu không đúng" for a wrong one', (
      tester,
    ) async {
      final auth = FakeAuthService();
      await auth.registerWithEmail(name: 'Linh', email: 'linh@fpt.edu.vn', password: 'breakbite1');
      await auth.signOut();
      final vm = await pumpSignIn(tester, auth);
      await tester.pump();

      await tester.enterText(field('s26.email'), 'linh@fpt.edu.vn');
      await tester.enterText(field('s26.password'), 'saimatkhau1');
      await tester.tap(find.bySemanticsIdentifier('s26.submit'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('s26.error'), findsOneWidget);
      expect(find.textContaining('không đúng'), findsOneWidget);
      expect(vm.user, isNull);

      await tester.enterText(field('s26.password'), 'breakbite1');
      await tester.tap(find.bySemanticsIdentifier('s26.submit'));
      await tester.pumpAndSettle();
      expect(vm.user?.displayName, 'Linh');
      expect(vm.message, isNull);
    });
  });
}
