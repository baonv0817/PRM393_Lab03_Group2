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

void main() {
  test('successful sign-in sets the user, logs the login event and the user id', () async {
    final analytics = FakeAnalyticsService();
    final crash = FakeCrashService();
    final vm = AuthViewModel(FakeAuthService(), analytics, crash);
    await Future<void>.delayed(Duration.zero);
    expect(vm.initialized, isTrue);
    expect(vm.user, isNull);

    await vm.signIn();
    await Future<void>.delayed(Duration.zero);
    expect(vm.user?.uid, 'dev-user');
    expect(analytics.userId, 'dev-user');
    expect(analytics.events.map((e) => e.name), contains('login'));
    expect(crash.keys['uid'], 'dev-user');
    vm.dispose();
  });

  test('cancelled sign-in shows a message, keeps no user and logs nothing to Crashlytics', () async {
    final crash = FakeCrashService();
    final vm = AuthViewModel(_FailingAuth(const CancelledException()), FakeAnalyticsService(), crash);
    await vm.signIn();
    expect(vm.user, isNull);
    expect(vm.message, contains('huỷ'));
    expect(vm.busy, isFalse);
    expect(crash.errors, isEmpty);
    vm.dispose();
  });

  test('failed sign-in shows the error message and records a non-fatal error', () async {
    final crash = FakeCrashService();
    final vm = AuthViewModel(
      _FailingAuth(const NetworkException(message: 'Không có mạng')),
      FakeAnalyticsService(),
      crash,
    );
    await vm.signIn();
    expect(vm.message, 'Không có mạng');
    expect(vm.busy, isFalse);
    expect(crash.errors, hasLength(1));
    vm.dispose();
  });

  test('onboarding is not done by default; completing it notifies the router once', () async {
    final vm = AuthViewModel(FakeAuthService(), FakeAnalyticsService(), FakeCrashService());
    var notified = 0;
    vm.addListener(() => notified++);
    expect(vm.onboardingDone, isFalse);
    vm.completeOnboarding();
    vm.completeOnboarding();
    expect(vm.onboardingDone, isTrue);
    expect(notified, 1);
    vm.dispose();
  });

  test('sign-out logs the logout event and clears the user', () async {
    final analytics = FakeAnalyticsService();
    final vm = AuthViewModel(FakeAuthService(signedIn: true), analytics, FakeCrashService());
    await Future<void>.delayed(Duration.zero);
    expect(vm.user, isNotNull);
    await vm.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(vm.user, isNull);
    expect(analytics.events.map((e) => e.name), contains('logout'));
    vm.dispose();
  });
}
