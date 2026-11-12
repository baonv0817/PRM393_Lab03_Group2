import 'package:breakbite/ui/profile/view_models/payment_settings_view_model.dart';
import 'package:breakbite/ui/profile/widgets/payment_settings_screen.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/widgets/test_id.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

class _BrokenProfile extends FakeUserRepository {
  @override
  Stream<UserProfile> watchProfile(String uid) => Stream.error(const NetworkException());
}

Finder byId(String id) => find.byWidgetPredicate((w) => w is TestId && w.id == id);

PaymentSettingsViewModel build(FakeUserRepository users, {FakeCrashService? crash}) =>
    PaymentSettingsViewModel(users: users, crash: crash ?? FakeCrashService(), uid: 'u1');

Future<void> pumpPayment(WidgetTester tester, FakeUserRepository users, {Size size = TestScreens.narrow}) async {
  final vm = build(users);
  addTearDown(vm.dispose);
  await pumpScreen(
    tester,
    const PaymentSettingsScreen(),
    providers: [ChangeNotifierProvider<PaymentSettingsViewModel>.value(value: vm)],
    size: size,
  );
}

void main() {
  group('PaymentSettingsViewModel', () {
    test('without a saved method MoMo is preselected and can be saved', () async {
      final vm = build(FakeUserRepository());
      await pumpEventQueue();
      expect(vm.chosen, PaymentMethod.momo);
      expect(vm.hasChanges, isTrue);
      vm.dispose();
    });

    test('saving stores the chosen method as the default', () async {
      final users = FakeUserRepository();
      final vm = build(users);
      await pumpEventQueue();
      vm.choose(PaymentMethod.cash);
      final result = await vm.save.execute();
      expect((result! as Ok<PaymentMethod>).value, PaymentMethod.cash);
      expect(users.profileOf('u1').defaultPaymentMethod, PaymentMethod.cash);
      await pumpEventQueue();
      expect(vm.hasChanges, isFalse);
      vm.dispose();
    });

    test('a saved method is shown and a failed save is recorded', () async {
      final users = FakeUserRepository();
      await users.setDefaultPaymentMethod('u1', PaymentMethod.vnpay);
      final crash = FakeCrashService();
      final vm = build(users, crash: crash);
      await pumpEventQueue();
      expect(vm.chosen, PaymentMethod.vnpay);
      expect(vm.hasChanges, isFalse);
      vm.choose(PaymentMethod.card);
      users.failNextWrite = const NetworkException();
      final result = await vm.save.execute();
      expect((result! as Err<PaymentMethod>).error, isA<NetworkException>());
      expect(crash.errors, hasLength(1));
      vm.dispose();
    });
  });

  group('screen', () {
    for (final size in [TestScreens.narrow, TestScreens.wide]) {
      testWidgets('shows the four methods and the save button at ${size.width.round()} dp', (tester) async {
        await pumpPayment(tester, FakeUserRepository(), size: size);
        for (final method in PaymentMethod.values) {
          expect(byId('s17.method.${method.name}'), findsOneWidget, reason: method.name);
        }
        expect(byId('s17.save'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('choosing cash and saving confirms it', (tester) async {
      final users = FakeUserRepository();
      await pumpPayment(tester, users);
      await tester.tap(byId('s17.method.cash'));
      await tester.pump();
      expect(tester.getSemantics(find.bySemanticsIdentifier('s17.method.cash')), isSemantics(isSelected: true));
      await tester.tap(byId('s17.save'));
      await tester.pumpAndSettle();
      expect(find.text('Đã đặt Tiền mặt tại kiosk làm mặc định.'), findsOneWidget);
      expect(users.profileOf('u1').defaultPaymentMethod, PaymentMethod.cash);
    });

    testWidgets('settings that cannot load offer a retry button', (tester) async {
      await pumpPayment(tester, _BrokenProfile());
      expect(byId('s17.retry'), findsOneWidget);
    });
  });
}
