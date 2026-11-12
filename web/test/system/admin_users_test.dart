import 'package:breakbite_admin/ui/system/users/view_models/admin_users_view_model.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_menu_repository.dart';
import 'fakes/system_fakes.dart';
import 'harness.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

AdminUsersViewModel _vm(FakeAdminUserRepository users, {String self = 'dev-admin'}) =>
    AdminUsersViewModel(users: users, menu: FakeMenuRepository(), selfUid: self);

void main() {
  group('AdminUsersViewModel (A01)', () {
    test('lists the accounts, counts each role, and filters by role and by a search without accents', () async {
      final vm = _vm(FakeAdminUserRepository(FakeAuditLog()));
      await pumpEventQueue();

      expect(vm.visible.map((u) => u.uid), containsAll(['dev-admin', 'staff-1', 'user-1', 'user-2']));
      expect((vm.countOf(UserRole.user), vm.countOf(UserRole.staff), vm.countOf(UserRole.admin)), (2, 1, 1));

      vm.setRoleFilter(UserRole.staff);
      expect(vm.visible.single.uid, 'staff-1');
      vm.setRoleFilter(null);

      vm.setQuery('tran bao');
      expect(vm.visible.single.uid, 'user-2', reason: 'Trần Bảo An, found without the accents');
      vm.setQuery('QUAN@fpt');
      expect(vm.visible.single.uid, 'user-1', reason: 'by email, any case');
      vm.setQuery('khong co ai');
      expect(vm.visible, isEmpty);
      vm.dispose();
    });

    test('an admin cannot change their own role, nor make a staff member without a kiosk', () async {
      final users = FakeAdminUserRepository(FakeAuditLog());
      final vm = _vm(users);
      await pumpEventQueue();

      final self = await vm.setAccess.execute(const AccessChange(uid: 'dev-admin', role: UserRole.user));
      expect((self! as Err<void>).error.message, AdminUsersViewModel.selfMessage);
      expect(users.byUid('dev-admin').role, UserRole.admin);

      final noKiosk = await vm.setAccess.execute(const AccessChange(uid: 'user-1', role: UserRole.staff));
      expect((noKiosk! as Err<void>).error, isA<ValidationException>());
      expect(users.byUid('user-1').role, UserRole.user);
      expect(vm.isSelf(users.byUid('dev-admin')), isTrue);
      vm.dispose();
    });

    test('making someone staff of a kiosk, and back to a customer, is saved and written in the audit log', () async {
      final audit = FakeAuditLog();
      final users = FakeAdminUserRepository(audit);
      final vm = _vm(users);
      await pumpEventQueue();

      final made = await vm.setAccess.execute(
        const AccessChange(uid: 'user-1', role: UserRole.staff, kioskId: 'q9-t4'),
      );
      expect(made!.isOk, isTrue);
      expect((users.byUid('user-1').role, users.byUid('user-1').kioskId), (UserRole.staff, 'q9-t4'));
      expect(audit.entries.single.action, AuditAction.userAccess);
      expect(audit.entries.single.target, 'users/user-1');
      expect(audit.entries.single.summary, contains('q9-t4'));

      await vm.setAccess.execute(const AccessChange(uid: 'user-1', role: UserRole.user));
      expect(users.byUid('user-1').role, UserRole.user);
      expect(users.byUid('user-1').kioskId, isNull, reason: 'the kiosk goes');
      expect(audit.entries, hasLength(2));
      vm.dispose();
    });

    test('a kiosk that does not exist and a failed write are errors that change nothing', () async {
      final audit = FakeAuditLog();
      final users = FakeAdminUserRepository(audit);
      final vm = _vm(users);
      await pumpEventQueue();

      final unknown = await vm.setAccess.execute(
        const AccessChange(uid: 'user-1', role: UserRole.staff, kioskId: 'nope'),
      );
      expect((unknown! as Err<void>).error.message, contains('nope'));
      users.failNext = const NetworkException();
      final offline = await vm.setAccess.execute(const AccessChange(uid: 'user-1', role: UserRole.admin));
      expect((offline! as Err<void>).error, isA<NetworkException>());
      expect(users.byUid('user-1').role, UserRole.user);
      expect(audit.entries, isEmpty);
      vm.dispose();
    });

    test('shows the kiosk name of a staff member, and the id when the kiosk is not known', () async {
      final vm = _vm(FakeAdminUserRepository(FakeAuditLog()));
      await pumpEventQueue();
      expect(vm.kioskName('q9-t2'), 'Kiosk Q9 · Tầng 2');
      expect(vm.kioskName('somewhere'), 'somewhere');
      expect(vm.kioskName(null), '');
      vm.dispose();
    });
  });

  group('A01 on screen', () {
    Future<FakeAdminUserRepository> open(WidgetTester tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1280, 900);
      addTearDown(tester.view.reset);
      final deps = await pumpSystemApp(tester);
      await goToPage(tester, 'Người dùng');
      return deps.users;
    }

    testWidgets('lists every account, marks the admin as "bạn" and cannot edit them', (tester) async {
      await open(tester);
      expect(byId('a01.row.user-1'), findsOneWidget);
      expect(byId('a01.row.staff-1'), findsOneWidget);
      expect(find.textContaining('(bạn)'), findsOneWidget);
      final edit = tester.widget<OutlinedButton>(
        find.descendant(of: byId('a01.edit.dev-admin'), matching: find.byType(OutlinedButton)),
      );
      expect(edit.onPressed, isNull);
    });

    testWidgets('the search box and the role chips narrow the list', (tester) async {
      await open(tester);
      await tester.enterText(find.descendant(of: byId('a01.search'), matching: find.byType(TextField)), 'hanh');
      await tester.pumpAndSettle();
      expect(byId('a01.row.staff-1'), findsOneWidget);
      expect(byId('a01.row.user-1'), findsNothing);

      await tester.enterText(find.descendant(of: byId('a01.search'), matching: find.byType(TextField)), '');
      await tester.tap(byId('a01.filter.user'));
      await tester.pumpAndSettle();
      expect(byId('a01.row.user-1'), findsOneWidget);
      expect(byId('a01.row.staff-1'), findsNothing);
    });

    testWidgets('a customer is made staff of a kiosk in the dialog, and the change is saved with its audit line', (
      tester,
    ) async {
      final users = await open(tester);
      await tester.tap(byId('a01.edit.user-1'));
      await tester.pumpAndSettle();
      expect(byId('a01.kiosk'), findsNothing, reason: 'the kiosk is asked for staff only');

      await tester.tap(byId('a01.role.staff'));
      await tester.pumpAndSettle();
      expect(byId('a01.kiosk'), findsOneWidget);
      await tester.tap(byId('a01.save'));
      await tester.pumpAndSettle();

      final user = users.byUid('user-1');
      expect(user.role, UserRole.staff);
      expect(user.kioskId, isNotNull);
      expect(users.audit.entries.single.action, AuditAction.userAccess);
      expect(find.textContaining('Đã đặt'), findsOneWidget);
    });

    testWidgets('"Lưu" stays off while nothing has changed', (tester) async {
      await open(tester);
      await tester.tap(byId('a01.edit.user-1'));
      await tester.pumpAndSettle();
      final save = tester.widget<FilledButton>(
        find.descendant(of: byId('a01.save'), matching: find.byType(FilledButton)),
      );
      expect(save.onPressed, isNull);
    });
  });
}
