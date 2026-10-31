import '../../../dev/fakes/fakes.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingAuth extends FakeAuthService {
  _ThrowingAuth(this.error);

  final Exception error;

  @override
  Future<AppUser> signInWithGoogle() async => throw error;
}

void main() {
  test('đăng nhập thành công: có user, ghi sự kiện login và đặt user id', () async {
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

  test('huỷ đăng nhập: hiện thông báo, không có user', () async {
    final vm = AuthViewModel(_ThrowingAuth(const AuthCancelled()), FakeAnalyticsService(), FakeCrashService());
    await vm.signIn();
    expect(vm.user, isNull);
    expect(vm.message, contains('huỷ'));
    expect(vm.busy, isFalse);
    vm.dispose();
  });

  test('đăng nhập lỗi: hiện thông báo và ghi lỗi không gây crash', () async {
    final crash = FakeCrashService();
    final vm = AuthViewModel(_ThrowingAuth(const AuthFailure('Không có mạng')), FakeAnalyticsService(), crash);
    await vm.signIn();
    expect(vm.message, 'Không có mạng');
    expect(crash.errors, hasLength(1));
    vm.dispose();
  });

  test('Onboarding: mặc định chưa xem, hoàn tất thì báo cho router một lần', () async {
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

  test('đăng xuất ghi sự kiện logout và xoá user', () async {
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
