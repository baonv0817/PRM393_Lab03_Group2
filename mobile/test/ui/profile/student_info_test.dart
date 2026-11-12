import 'package:breakbite/ui/profile/view_models/student_info_view_model.dart';
import 'package:breakbite/ui/profile/widgets/student_info_screen.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
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

Finder fieldOf(String id) => find.descendant(of: byId(id), matching: find.byType(TextField));

StudentInfoViewModel build(FakeUserRepository users, {FakeCrashService? crash}) =>
    StudentInfoViewModel(users: users, menu: FakeMenuRepository(), crash: crash ?? FakeCrashService(), uid: 'u1');

Future<StudentInfoViewModel> pumpInfo(
  WidgetTester tester,
  FakeUserRepository users, {
  Size size = TestScreens.narrow,
}) async {
  final vm = build(users);
  addTearDown(vm.dispose);
  await pumpScreen(
    tester,
    const StudentInfoScreen(),
    providers: [ChangeNotifierProvider<StudentInfoViewModel>.value(value: vm)],
    size: size,
  );
  return vm;
}

void main() {
  group('StudentInfoViewModel', () {
    test('fills the form from the saved profile and has nothing to save yet', () async {
      final vm = build(FakeUserRepository());
      await pumpEventQueue();
      expect(vm.profile, isA<ViewData<UserProfile>>());
      expect(vm.name, 'Minh Quân');
      expect(vm.kiosks, hasLength(3));
      expect(vm.hasChanges, isFalse);
      vm.dispose();
    });

    test('saves a valid profile, normalized, including the default kiosk', () async {
      final users = FakeUserRepository();
      final vm = build(users);
      await pumpEventQueue();
      vm
        ..setName('  Nguyễn Minh Quân ')
        ..setStudentId('se183398')
        ..setPhone('+84 912 345 678')
        ..setDefaultKiosk('q9-t4');
      expect(vm.hasChanges, isTrue);
      final result = await vm.save.execute();
      expect(result, isA<Ok<void>>());
      final saved = users.profileOf('u1');
      expect(saved.displayName, 'Nguyễn Minh Quân');
      expect(saved.studentId, 'SE183398');
      expect(saved.phone, '0912345678');
      expect(saved.defaultKioskId, 'q9-t4');
      await pumpEventQueue();
      expect(vm.hasChanges, isFalse);
      vm.dispose();
    });

    test('invalid fields show their errors after the first save and nothing is written', () async {
      final users = FakeUserRepository();
      final vm = build(users);
      await pumpEventQueue();
      vm
        ..setStudentId('12')
        ..setPhone('123');
      expect(vm.studentIdError, isNull);
      final result = await vm.save.execute();
      expect((result! as Err<void>).error, isA<ValidationException>());
      expect(vm.studentIdError, isNotNull);
      expect(vm.phoneError, isNotNull);
      expect(users.saves, 0);
      vm.dispose();
    });

    test('a failed save is reported and recorded', () async {
      final users = FakeUserRepository();
      final crash = FakeCrashService();
      final vm = build(users, crash: crash);
      await pumpEventQueue();
      vm.setName('Quân');
      users.failNextWrite = const NetworkException();
      final result = await vm.save.execute();
      expect((result! as Err<void>).error, isA<NetworkException>());
      expect(crash.errors, hasLength(1));
      vm.dispose();
    });
  });

  group('screen', () {
    for (final size in [TestScreens.narrow, TestScreens.wide]) {
      testWidgets('shows every field and the save button at ${size.width.round()} dp', (tester) async {
        await pumpInfo(tester, FakeUserRepository(), size: size);
        for (final id in ['s16.name', 's16.studentId', 's16.phone', 's16.defaultKiosk', 's16.save']) {
          expect(byId(id), findsOneWidget, reason: id);
        }
        expect(find.text('Không bắt buộc. Bạn vẫn đặt món được khi chưa điền.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a wrong student ID shows its error after saving; fixing it saves', (tester) async {
      final users = FakeUserRepository();
      await pumpInfo(tester, users);
      await tester.enterText(fieldOf('s16.studentId'), 'SE12');
      await tester.pump();
      await tester.tap(byId('s16.save'));
      await tester.pumpAndSettle();
      expect(find.text('MSSV gồm 2 chữ cái và 6 chữ số, ví dụ SE183398.'), findsOneWidget);
      await tester.enterText(fieldOf('s16.studentId'), 'se183398');
      await tester.pump();
      await tester.tap(byId('s16.save'));
      await tester.pumpAndSettle();
      expect(find.text('Đã lưu hồ sơ.'), findsOneWidget);
      expect(users.profileOf('u1').studentId, 'SE183398');
    });

    testWidgets('a profile that cannot load offers a retry button', (tester) async {
      await pumpInfo(tester, _BrokenProfile());
      expect(byId('s16.retry'), findsOneWidget);
    });
  });
}
