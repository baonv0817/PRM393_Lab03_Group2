import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/profile/view_models/profile_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_screen.dart';
import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';
import '../../helpers/pump.dart';

class _FailingCount extends FakeOrderRepository {
  bool fail = true;

  @override
  Future<Result<int>> countMyOrders(String uid) async =>
      fail ? const Result.error(NetworkException()) : super.countMyOrders(uid);
}

Future<void> pumpProfile(WidgetTester tester, ProfileViewModel profile, {Size size = TestScreens.narrow}) async {
  final auth = AuthViewModel(
    FakeAuthService(signedIn: true),
    FakeAnalyticsService(),
    FakeCrashService(),
    InMemorySessionRepository(),
    FakeMessagingService(),
  );
  addTearDown(auth.dispose);
  await pumpScreen(
    tester,
    const ProfileScreen(),
    providers: [
      ChangeNotifierProvider<AuthViewModel>.value(value: auth),
      ChangeNotifierProvider<ProfileViewModel>.value(value: profile),
    ],
    size: size,
  );
}

void main() {
  test('the order count comes from the repository', () async {
    final orders = FakeOrderRepository();
    await placeTestOrder(orders, uid: 'u1');
    await placeTestOrder(orders, uid: 'u1');
    await placeTestOrder(orders, uid: 'someone-else');
    final vm = ProfileViewModel(orders: orders, crash: FakeCrashService(), uid: 'u1');
    await pumpEventQueue();
    expect(vm.orderCount.dataOrNull, 2);
    expect(vm.orderCountLabel, '2 đơn đã đặt');
    vm.dispose();
  });

  test('a failed count shows an error state, records a non-fatal error and can be retried', () async {
    final orders = _FailingCount();
    final crash = FakeCrashService();
    final vm = ProfileViewModel(orders: orders, crash: crash, uid: 'u1');
    await pumpEventQueue();
    expect(vm.orderCount, isA<ViewError<int>>());
    expect(crash.errors, hasLength(1));
    orders.fail = false;
    await vm.load();
    expect(vm.orderCount.dataOrNull, 0);
    vm.dispose();
  });

  testWidgets('shows the name, the order count, every entry and the sign-out button', (tester) async {
    final vm = ProfileViewModel(orders: FakeOrderRepository(), crash: FakeCrashService(), uid: 'dev-user');
    addTearDown(vm.dispose);
    await pumpProfile(tester, vm);
    expect(find.text('Minh Quân'), findsOneWidget);
    expect(find.text('0 đơn đã đặt'), findsOneWidget);
    for (final id in ['info', 'payment', 'notifications', 'favorites', 'history', 'firebaseDemo', 'signOut']) {
      await tester.scrollUntilVisible(find.bySemanticsIdentifier('s15.$id'), 100);
      expect(find.bySemanticsIdentifier('s15.$id'), findsOneWidget, reason: id);
    }
  });

  testWidgets('sign-out asks for confirmation; keeping the session signs nobody out', (tester) async {
    final vm = ProfileViewModel(orders: FakeOrderRepository(), crash: FakeCrashService(), uid: 'dev-user');
    addTearDown(vm.dispose);
    await pumpProfile(tester, vm, size: TestScreens.wide);
    await tester.tap(find.bySemanticsIdentifier('s15.signOut'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng xuất?'), findsOneWidget);
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(find.text('Minh Quân'), findsOneWidget);
  });

  testWidgets('a failed order count offers a retry button', (tester) async {
    final orders = _FailingCount();
    final vm = ProfileViewModel(orders: orders, crash: FakeCrashService(), uid: 'dev-user');
    addTearDown(vm.dispose);
    await pumpProfile(tester, vm);
    expect(find.text('Không tải được số đơn'), findsOneWidget);
    orders.fail = false;
    await tester.tap(find.bySemanticsIdentifier('s15.retry'));
    await tester.pumpAndSettle();
    expect(find.text('0 đơn đã đặt'), findsOneWidget);
  });
}
