import 'dart:async';

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

class _AuthWithDefaultKiosk extends FakeAuthService {
  _AuthWithDefaultKiosk(this.defaultKioskId) : super(signedIn: true);

  final String defaultKioskId;

  @override
  Stream<AppUser?> authStateChanges() =>
      Stream.value(AppUser(uid: 'u1', displayName: 'Quân', role: UserRole.user, defaultKioskId: defaultKioskId));
}

AuthViewModel make({
  FakeAuthService? auth,
  FakeAnalyticsService? analytics,
  FakeCrashService? crash,
  InMemorySessionRepository? session,
  FakeMessagingService? messaging,
}) => AuthViewModel(
  auth ?? FakeAuthService(),
  analytics ?? FakeAnalyticsService(),
  crash ?? FakeCrashService(),
  session ?? InMemorySessionRepository(),
  messaging ?? FakeMessagingService(),
);

class _HangingMessaging extends FakeMessagingService {
  @override
  Future<void> detachUser(String uid) => Completer<void>().future; // never answers
}

void main() {
  testWidgets('sign-out is not held up for ever by a push service that never answers', (tester) async {
    final vm = make(auth: FakeAuthService(signedIn: true), messaging: _HangingMessaging());
    await tester.pump();
    expect(vm.user, isNotNull);

    Result<void>? result;
    unawaited(vm.signOut.execute().then((r) => result = r));
    await tester.pump();
    expect(result, isNull, reason: 'it waits a little for the push service');
    expect(vm.signOut.running, isTrue);

    await tester.pump(const Duration(seconds: 5));
    expect(result?.isOk, isTrue, reason: 'then it signs out anyway');
    expect(vm.user, isNull);
    expect(vm.signOut.running, isFalse);
    vm.dispose();
  });

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

  test('a new user is attached to push messaging, asked for permission and tagged in Crashlytics', () async {
    final messaging = FakeMessagingService();
    final crash = FakeCrashService();
    final vm = make(
      auth: FakeAuthService(role: UserRole.staff, signedIn: true),
      messaging: messaging,
      crash: crash,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(messaging.attached, ['dev-staff']);
    expect(messaging.permissionRequests, 1);
    expect(crash.keys['role'], 'staff');
    expect(crash.keys.containsKey('kiosk_id'), isTrue);
    vm.dispose();
  });

  test('the kiosk_id key in Crashlytics follows the kiosk a customer picks', () async {
    final crash = FakeCrashService();
    final session = InMemorySessionRepository();
    final vm = make(auth: FakeAuthService(signedIn: true), crash: crash, session: session);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(crash.keys['kiosk_id'], 'none');
    await session.selectKiosk('q9-t2');
    await Future<void>.delayed(Duration.zero);
    expect(crash.keys['kiosk_id'], 'q9-t2');
    vm.dispose();
  });

  test('sign-out detaches the device token before signing out', () async {
    final messaging = FakeMessagingService();
    final vm = make(auth: FakeAuthService(signedIn: true), messaging: messaging);
    await Future<void>.delayed(Duration.zero);
    await vm.signOut.execute();
    expect(messaging.detached, ['dev-user']);
    vm.dispose();
  });

  test('the login event is logged only for an explicit sign-in, not when a saved session is restored', () async {
    final analytics = FakeAnalyticsService();
    final vm = make(auth: FakeAuthService(signedIn: true), analytics: analytics);
    await Future<void>.delayed(Duration.zero);
    expect(analytics.userId, 'dev-user');
    expect(analytics.events.map((e) => e.name), isNot(contains('login')));
    vm.dispose();
  });

  test('signing in picks the default kiosk saved in the profile', () async {
    final session = InMemorySessionRepository(selectedKioskId: 'q9-t2');
    final vm = make(auth: _AuthWithDefaultKiosk('q9-t4'), session: session);
    await pumpEventQueue();
    expect(session.selectedKioskId, 'q9-t4');
    vm.dispose();
  });

  test('without a default kiosk the current choice is kept', () async {
    final session = InMemorySessionRepository(selectedKioskId: 'q9-t2');
    final vm = make(auth: FakeAuthService(signedIn: true), session: session);
    await pumpEventQueue();
    expect(session.selectedKioskId, 'q9-t2');
    vm.dispose();
  });
}
