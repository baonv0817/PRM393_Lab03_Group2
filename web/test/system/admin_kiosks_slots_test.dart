import 'package:breakbite_admin/ui/system/kiosks/view_models/admin_kiosks_view_model.dart';
import 'package:breakbite_admin/ui/system/slots/view_models/admin_slots_view_model.dart';
import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_menu_repository.dart';
import 'fakes/system_fakes.dart';
import 'harness.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Finder field(String id) => find.descendant(of: byId(id), matching: find.byType(TextField));

// Wednesday 11 November 2026, 07:00 in Vietnam.
final _now = DateTime.utc(2026, 11, 10, 24);

(FakeMenuRepository, FakeAdminKioskRepository, FakeAuditLog) _kioskParts() {
  final audit = FakeAuditLog();
  final menu = FakeMenuRepository();
  return (menu, FakeAdminKioskRepository(menu, audit), audit);
}

void main() {
  group('AdminKiosksViewModel (A02)', () {
    test('checks a form: a name, a free-looking id, numbers, and hours that come in pairs', () async {
      final (menu, kiosks, _) = _kioskParts();
      final vm = AdminKiosksViewModel(menu: menu, kiosks: kiosks);
      await pumpEventQueue();

      expect(vm.problemOf(const KioskForm(id: 'k1'), isNew: true), 'Nhập tên kiosk.');
      expect(vm.problemOf(const KioskForm(name: 'Kiosk A', id: 'Bad Id'), isNew: true), contains('Mã kiosk'));
      expect(vm.problemOf(const KioskForm(name: 'Kiosk A', id: 'k1', wait: 'x'), isNew: true), contains('là số'));
      expect(vm.problemOf(const KioskForm(name: 'Kiosk A', id: 'k1', wait: '500'), isNew: true), contains('0 đến'));
      expect(
        vm.problemOf(const KioskForm(name: 'Kiosk A', id: 'k1', openTime: '06:30'), isNew: true),
        contains('đủ giờ'),
      );
      expect(
        vm.problemOf(const KioskForm(name: 'Kiosk A', id: 'k1', openTime: '6:30', closeTime: '17:00'), isNew: true),
        contains('06:30'),
      );
      expect(
        vm.problemOf(const KioskForm(name: 'Kiosk A', id: 'k1', maxOrders: '0'), isNew: true),
        contains('lớn hơn 0'),
      );
      expect(
        vm.problemOf(const KioskForm(name: 'Kiosk A', id: 'k1', openTime: '06:30', closeTime: '17:00'), isNew: true),
        isNull,
      );
      expect(
        vm.problemOf(const KioskForm(name: 'Kiosk A'), isNew: false),
        isNull,
        reason: 'an existing kiosk keeps its id',
      );
      vm.dispose();
    });

    test('the id of a new kiosk comes from its name, without accents', () {
      expect(AdminKiosksViewModel.idFor('Nhà văn hóa SV · Tầng 1'), 'nha-van-hoa-sv-tang-1');
    });

    test('adding a kiosk saves it with its audit line; a taken id and a failed write change nothing', () async {
      final (menu, kiosks, audit) = _kioskParts();
      final vm = AdminKiosksViewModel(menu: menu, kiosks: kiosks);
      await pumpEventQueue();

      final added = await vm.save.execute((
        form: const KioskForm(
          id: 'q12-t1',
          name: 'Kiosk Q12',
          location: 'Campus Q12',
          wait: '8',
          openTime: '07:00',
          closeTime: '16:00',
        ),
        isNew: true,
      ));
      expect(added!.isOk, isTrue);
      final kiosk = menu.kiosks.firstWhere((k) => k.id == 'q12-t1');
      expect((kiosk.name, kiosk.waitMinutes, kiosk.openTime, kiosk.closeTime), ('Kiosk Q12', 8, '07:00', '16:00'));
      expect(audit.entries.single.action, AuditAction.kioskSave);

      final taken = await vm.save.execute((form: const KioskForm(id: 'q12-t1', name: 'Another'), isNew: true));
      expect((taken! as Err<void>).error.message, contains('đã có'));
      kiosks.failNext = const NetworkException();
      final offline = await vm.save.execute((form: const KioskForm(id: 'q12-t2', name: 'Offline'), isNew: true));
      expect((offline! as Err<void>).error, isA<NetworkException>());
      expect(menu.kiosks.where((k) => k.id == 'q12-t2'), isEmpty);
      expect(audit.entries, hasLength(1));
      vm.dispose();
    });

    test('editing keeps the id and the pause, and an empty field is taken off the kiosk', () async {
      final (menu, kiosks, _) = _kioskParts();
      final paused = DateTime(2030);
      menu.kiosks = [
        Kiosk(
          id: 'q9-t2',
          name: 'Kiosk Q9',
          open: true,
          waitMinutes: 6,
          openTime: '06:30',
          closeTime: '17:00',
          notice: 'Hi',
          pausedUntil: paused,
        ),
      ];
      final vm = AdminKiosksViewModel(menu: menu, kiosks: kiosks);
      await pumpEventQueue();

      await vm.save.execute((form: const KioskForm(id: 'q9-t2', name: 'Kiosk Q9 mới', wait: '9'), isNew: false));
      final kiosk = menu.kiosks.single;
      expect((kiosk.id, kiosk.name, kiosk.waitMinutes), ('q9-t2', 'Kiosk Q9 mới', 9));
      expect(kiosk.openTime, isNull);
      expect(kiosk.notice, isNull);
      expect(kiosk.pausedUntil, paused, reason: 'the pause belongs to the staff');

      final unknown = await vm.save.execute((form: const KioskForm(id: 'nope', name: 'X'), isNew: false));
      expect((unknown! as Err<void>).error, isA<NotFoundException>());
      vm.dispose();
    });
  });

  group('AdminSlotsViewModel (A03)', () {
    AdminSlotsViewModel makeVm(FakeAdminSlotRepository slots) =>
        AdminSlotsViewModel(menu: FakeMenuRepository(), slots: slots, clock: () => _now);

    test('opens on the first kiosk, and says when it has no windows to come', () async {
      final slots = FakeAdminSlotRepository(FakeAuditLog());
      final vm = makeVm(slots);
      await pumpEventQueue();
      expect(vm.kioskId, 'q9-t2');
      expect(vm.state, isA<ViewEmpty<List<PickupSlot>>>());
      vm.dispose();
    });

    test('the form starts with the same breaks as the seed, and checks what is typed', () async {
      final vm = makeVm(FakeAdminSlotRepository(FakeAuditLog()));
      await pumpEventQueue();
      expect(vm.breakStarts, ['08:45', '10:15', '13:15', '14:45']);
      expect(vm.problem, isNull);

      vm.setDays('abc');
      expect(vm.problem, contains('Số ngày'));
      vm.setDays('7');
      vm.setCapacity('0');
      expect(vm.problem, contains('Sức chứa'));
      vm.setCapacity('20');
      vm.addBreak('15:30');
      vm.addBreak('15:30');
      expect(vm.breakStarts.where((t) => t == '15:30'), hasLength(1), reason: 'a time already there is ignored');
      vm.removeBreak('08:45');
      expect(vm.breakStarts, ['10:15', '13:15', '14:45', '15:30']);
      vm.resetBreaks();
      expect(vm.breakStarts, hasLength(4));
      vm.dispose();
    });

    test('making the next days creates the windows once; asking again creates nothing and keeps bookings', () async {
      final audit = FakeAuditLog();
      final slots = FakeAdminSlotRepository(audit);
      final vm = makeVm(slots);
      await pumpEventQueue();
      vm
        ..setDays('1')
        ..removeBreak('10:15')
        ..removeBreak('13:15')
        ..removeBreak('14:45');
      slots.seed(
        'q9-t2',
        PickupSlot(
          id: '20261111-0845',
          startAt: DateTime.utc(2026, 11, 11, 1, 45),
          endAt: DateTime.utc(2026, 11, 11, 2),
          capacity: 15,
          booked: 9,
        ),
      );

      final first = await vm.create.execute();
      final made = (first! as Ok<SlotCreation>).value;
      expect((made.created, made.existing), (0, 1), reason: 'the one window of the day was already there');
      expect(slots.slotsOf('q9-t2').single.booked, 9, reason: 'its bookings are kept');
      expect(audit.entries, isEmpty, reason: 'nothing was made, nothing is written');

      vm
        ..addBreak('13:15')
        ..setDays('3');
      final second = await vm.create.execute();
      expect((second! as Ok<SlotCreation>).value.created, greaterThan(0));
      expect(audit.entries.single.action, AuditAction.slotsCreate);
      final again = await vm.create.execute();
      expect((again! as Ok<SlotCreation>).value.created, 0);
      expect(audit.entries, hasLength(1));
      vm.dispose();
    });

    test('a plan with a problem and a failed write are errors that create nothing', () async {
      final slots = FakeAdminSlotRepository(FakeAuditLog());
      final vm = makeVm(slots);
      await pumpEventQueue();
      vm.setCapacity('0');
      expect((await vm.create.execute())! is Err<SlotCreation>, isTrue);
      vm.setCapacity('15');
      slots.failNext = const NetworkException();
      expect(((await vm.create.execute())! as Err<SlotCreation>).error, isA<NetworkException>());
      expect(slots.slotsOf('q9-t2'), isEmpty);
      vm.dispose();
    });

    test('switching kiosk shows the windows of that kiosk', () async {
      final slots = FakeAdminSlotRepository(FakeAuditLog());
      slots.seed(
        'q9-t4',
        PickupSlot(
          id: '20261112-1015',
          startAt: DateTime.utc(2026, 11, 12, 3, 15),
          endAt: DateTime.utc(2026, 11, 12, 3, 30),
          capacity: 10,
          booked: 10,
        ),
      );
      final vm = makeVm(slots);
      await pumpEventQueue();
      vm.selectKiosk('q9-t4');
      await pumpEventQueue();
      expect(vm.kioskId, 'q9-t4');
      expect((vm.state as ViewData<List<PickupSlot>>).data.single.isFull, isTrue);
      vm.dispose();
    });
  });

  group('A02 and A03 on screen', () {
    Future<AdminDependenciesProbe> open(WidgetTester tester, String page) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1400, 1000);
      addTearDown(tester.view.reset);
      final deps = await pumpSystemApp(tester);
      await goToPage(tester, page);
      return AdminDependenciesProbe(deps.menu, deps.slots, deps.audit);
    }

    testWidgets('A02 lists the kiosks and adds one: the id follows the name, and the new kiosk appears', (
      tester,
    ) async {
      final probe = await open(tester, 'Kiosk');
      expect(byId('a02.row.q9-t2'), findsOneWidget);
      expect(find.text('Đang nhận đơn'), findsWidgets);

      await tester.tap(byId('a02.add'));
      await tester.pumpAndSettle();
      await tester.enterText(field('a02.name'), 'Kiosk Quận 12');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('a02.id')).controller!.text, 'kiosk-quan-12');
      await tester.tap(byId('a02.save'));
      await tester.pumpAndSettle();

      expect(probe.menu.kiosks.any((k) => k.id == 'kiosk-quan-12'), isTrue);
      expect(byId('a02.row.kiosk-quan-12'), findsOneWidget);
      expect(probe.audit.entries.single.action, AuditAction.kioskSave);
    });

    testWidgets('A02 shows what is wrong and does not save until the form is right', (tester) async {
      final probe = await open(tester, 'Kiosk');
      await tester.tap(byId('a02.add'));
      await tester.pumpAndSettle();
      await tester.tap(byId('a02.save'));
      await tester.pumpAndSettle();
      expect(byId('a02.error'), findsOneWidget);
      expect(find.text('Nhập tên kiosk.'), findsOneWidget);
      expect(probe.audit.entries, isEmpty);
    });

    testWidgets('A02 edits a kiosk: the id cannot be changed, the name can', (tester) async {
      final probe = await open(tester, 'Kiosk');
      await tester.tap(byId('a02.edit.q9-t2'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('a02.id')).enabled, isFalse);
      await tester.enterText(field('a02.name'), 'Kiosk Q9 Tầng 2 mới');
      await tester.pumpAndSettle();
      await tester.tap(byId('a02.save'));
      await tester.pumpAndSettle();
      expect(probe.menu.kiosks.firstWhere((k) => k.id == 'q9-t2').name, 'Kiosk Q9 Tầng 2 mới');
    });

    testWidgets('A03 makes the days to come for a kiosk and lists the windows', (tester) async {
      final probe = await open(tester, 'Khung giờ');
      expect(byId('a03.empty'), findsOneWidget);
      expect(byId('a03.preview'), findsOneWidget);

      await tester.enterText(field('a03.days'), '7');
      await tester.pumpAndSettle();
      await tester.tap(byId('a03.create'));
      await tester.pumpAndSettle();

      expect(probe.slots.slotsOf('q9-t2'), isNotEmpty);
      expect(find.textContaining('Đã tạo'), findsOneWidget);
      expect(find.textContaining('/15 đơn'), findsWidgets);
      expect(probe.audit.entries.single.action, AuditAction.slotsCreate);
    });

    testWidgets('A03 refuses a wrong plan: the button is off and the problem is shown', (tester) async {
      await open(tester, 'Khung giờ');
      await tester.enterText(field('a03.capacity'), '0');
      await tester.pumpAndSettle();
      expect(byId('a03.problem'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.descendant(of: byId('a03.create'), matching: find.byType(FilledButton)),
      );
      expect(button.onPressed, isNull);
    });
  });
}

class AdminDependenciesProbe {
  AdminDependenciesProbe(this.menu, this.slots, this.audit);

  final FakeMenuRepository menu;
  final FakeAdminSlotRepository slots;
  final FakeAuditLog audit;
}
