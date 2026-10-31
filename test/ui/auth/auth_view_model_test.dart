import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

class _FailingAuth extends FakeAuthService {
  _FailingAuth(this.error);

  final AppException error;

  @override
  Future<Result<AppUser>> signInWithGoogle() async => Result.error(error);
}

AuthViewModel make({
  FakeAuthService? auth,
  FakeAnalyticsService? analytics,
  FakeCrashService? crash,
  InMemorySessionRepository? session,
}) => AuthViewModel(
  auth ?? FakeAuthService(),
  analytics ?? FakeAnalyticsService(),
  crash ?? FakeCrashService(),
  session ?? InMemorySessionRepository(),
);

void main() {
  test('successful sign-in sets the user, logs the login event and the user id', () async {
    final analytics = FakeAnalyticsService();
    final crash = FakeCrashService();
    final vm = make(analytics: analytics, crash: crash);
    await Future<void>.delayed(Duration.zero);
    expect(vm.initialized, isTrue);
    expect(vm.user, isNull);

    final result = await vm.signIn.execute();
    await Future<void>.delayed(Duration.zero);
    expect(result!.isOk, isTrue);
    expect(vm.signIn.completed, isTrue);
    expect(vm.user?.uid, 'dev-user');
    expect(analytics.userId, 'dev-user');
    expect(analytics.events.map((e) => e.name), contains('login'));
    expect(crash.keys['uid'], 'dev-user');
    vm.dispose();
  });

  test('cancelled sign-in shows a message, keeps no user and logs nothing to Crashlytics', () async {
    final crash = FakeCrashService();
    final vm = make(auth: _FailingAuth(const CancelledException()), crash: crash);
    await vm.signIn.execute();
    expect(vm.user, isNull);
    expect(vm.message, contains('huỷ'));
    expect(vm.signIn.running, isFalse);
    expect(vm.signIn.failed, isTrue);
    expect(crash.errors, isEmpty);
    vm.dispose();
  });

  test('failed sign-in shows the error message and records a non-fatal error', () async {
    final crash = FakeCrashService();
    final vm = make(
      auth: _FailingAuth(const NetworkException(message: 'Không có mạng')),
      crash: crash,
    );
    await vm.signIn.execute();
    expect(vm.message, 'Không có mạng');
    expect(vm.signIn.running, isFalse);
    expect(crash.errors, hasLength(1));
    vm.dispose();
  });

  test('onboarding is not done by default; completing it notifies the router once', () async {
    final vm = make();
    var notified = 0;
    vm.addListener(() => notified++);
    expect(vm.onboardingDone, isFalse);
    vm.completeOnboarding();
    vm.completeOnboarding();
    expect(vm.onboardingDone, isTrue);
    expect(notified, 1);
    vm.dispose();
  });

  test('sign-out logs the logout event, clears the user and the data kept on the device', () async {
    final analytics = FakeAnalyticsService();
    final session = InMemorySessionRepository(selectedKioskId: 'q9-t2');
    final vm = make(auth: FakeAuthService(signedIn: true), analytics: analytics, session: session);
    await Future<void>.delayed(Duration.zero);
    expect(vm.user, isNotNull);
    await vm.signOut.execute();
    await Future<void>.delayed(Duration.zero);
    expect(vm.user, isNull);
    expect(session.selectedKioskId, isNull);
    expect(analytics.events.map((e) => e.name), contains('logout'));
    vm.dispose();
  });
}
