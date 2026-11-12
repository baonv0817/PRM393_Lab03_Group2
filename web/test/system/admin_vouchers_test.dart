import 'package:breakbite_admin/ui/system/vouchers/view_models/admin_vouchers_view_model.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/system_fakes.dart';
import 'harness.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Finder field(String id) => find.descendant(of: byId(id), matching: find.byType(TextField));

// Wednesday 11 November 2026, midday in Vietnam.
final _now = DateTime.utc(2026, 11, 11, 5);

VoucherForm _fixed({String code = 'NEW10K', DateTime? expiresOn}) => VoucherForm(
  code: code,
  title: 'Giảm 10K',
  amount: '10000',
  minOrder: '40000',
  expiresOn: expiresOn ?? DateTime.utc(2026, 12, 31),
);

void main() {
  group('VoucherForm', () {
    test('turns the days into Vietnam time: from 00:00 of the first day to 23:59 of the last', () {
      final voucher = VoucherForm(
        code: 'abc',
        title: 'T',
        amount: '5000',
        startsOn: DateTime.utc(2026, 11, 12),
        expiresOn: DateTime.utc(2026, 11, 30),
      ).toVoucher()!;
      expect(voucher.code, 'ABC', reason: 'upper case');
      expect(voucher.startsAt, DateTime.utc(2026, 11, 11, 17), reason: '00:00 on the 12th in Vietnam');
      expect(voucher.expiresAt, DateTime.utc(2026, 11, 30, 16, 59, 59), reason: '23:59:59 on the 30th in Vietnam');
    });

    test('reads a voucher back into the same days, whatever the computer time zone', () {
      final voucher = VoucherForm(
        code: 'ABC',
        title: 'T',
        amount: '5000',
        startsOn: DateTime.utc(2026, 11, 12),
        expiresOn: DateTime.utc(2026, 11, 30),
      ).toVoucher()!;
      final back = VoucherForm.of(voucher);
      expect((back.startsOn, back.expiresOn), (DateTime.utc(2026, 11, 12), DateTime.utc(2026, 11, 30)));
      expect((back.kind, back.amount), (DiscountKind.fixed, '5000'));

      final percent = VoucherForm.of(
        Voucher(code: 'P', discount: const PercentDiscount(percent: 15, maxVnd: 15000), expiresAt: DateTime.utc(2100)),
      );
      expect((percent.kind, percent.percent, percent.maxVnd), (DiscountKind.percent, '15', '15000'));
    });

    test('has no voucher while a number is not a number or there is no last day', () {
      expect(
        const VoucherForm(code: 'ABC', title: 'T', amount: '5000').toVoucher(),
        isNull,
        reason: 'no last day',
      );
      expect(VoucherForm(code: 'ABC', title: 'T', amount: 'x', expiresOn: DateTime.utc(2027)).toVoucher(), isNull);
      expect(
        VoucherForm(
          code: 'ABC',
          title: 'T',
          kind: DiscountKind.percent,
          percent: '10',
          expiresOn: DateTime.utc(2027),
        ).toVoucher(),
        isNull,
        reason: 'a percentage needs its cap',
      );
    });
  });

  group('VoucherRules', () {
    Voucher make({
      String code = 'ABC',
      String title = 'T',
      VoucherDiscount? discount,
      String? from,
      String? to,
      DateTime? starts,
    }) => Voucher(
      code: code,
      title: title,
      discount: discount ?? const FixedDiscount(5000),
      expiresAt: DateTime.utc(2100),
      activeFrom: from,
      activeTo: to,
      startsAt: starts,
    );

    test('refuses what the database rules would refuse, with a sentence', () {
      expect(VoucherRules.problemOf(make(code: 'ab'), isNew: true), contains('Mã gồm'));
      expect(
        VoucherRules.problemOf(make(code: 'ab'), isNew: false),
        isNull,
        reason: 'an existing code is not checked again',
      );
      expect(VoucherRules.problemOf(make(title: ' '), isNew: true), contains('tên'));
      expect(VoucherRules.problemOf(make(discount: const FixedDiscount(0)), isNew: true), contains('lớn hơn 0'));
      expect(
        VoucherRules.problemOf(make(discount: const PercentDiscount(percent: 101, maxVnd: 1000)), isNew: true),
        contains('1 đến 100'),
      );
      expect(
        VoucherRules.problemOf(make(discount: const PercentDiscount(percent: 10, maxVnd: 0)), isNew: true),
        contains('tối đa'),
      );
      expect(VoucherRules.problemOf(make(from: '10:15'), isNew: true), contains('đủ giờ'));
      expect(VoucherRules.problemOf(make(from: '10:15', to: '25:00'), isNew: true), contains('10:15'));
      expect(VoucherRules.problemOf(make(starts: DateTime.utc(2101)), isNew: true), contains('trước'));
      expect(VoucherRules.problemOf(make(from: '10:15', to: '10:30'), isNew: true), isNull);
    });
  });

  group('AdminVouchersViewModel (A04)', () {
    AdminVouchersViewModel makeVm(FakeAdminVoucherRepository repo) =>
        AdminVouchersViewModel(vouchers: repo, clock: () => _now);

    test('says where each voucher stands, and filters by it', () async {
      final repo = FakeAdminVoucherRepository(FakeAuditLog());
      final vm = makeVm(repo);
      await pumpEventQueue();

      expect(vm.statusOf(repo.byCode('BBSTUDENT')), VoucherStatus.live);
      expect(vm.statusOf(repo.byCode('OLD2020')), VoucherStatus.expired);
      await vm.toggle.execute((code: 'BBSTUDENT', active: false));
      expect(vm.statusOf(repo.byCode('BBSTUDENT')), VoucherStatus.off);

      vm.setFilter(VoucherFilter.live);
      expect(vm.visible.map((v) => v.code), ['GOLDEN15']);
      vm.setFilter(VoucherFilter.expired);
      expect(vm.visible.map((v) => v.code), ['OLD2020']);
      vm.setFilter(VoucherFilter.off);
      expect(vm.visible.map((v) => v.code), ['BBSTUDENT']);
      vm.dispose();
    });

    test('a voucher that starts later is scheduled, not live', () async {
      final repo = FakeAdminVoucherRepository(
        FakeAuditLog(),
        vouchers: [
          Voucher(
            code: 'SOON',
            discount: const FixedDiscount(1000),
            expiresAt: DateTime.utc(2100),
            startsAt: DateTime.utc(2027),
          ),
        ],
      );
      final vm = makeVm(repo);
      await pumpEventQueue();
      expect(vm.statusOf(repo.byCode('SOON')), VoucherStatus.scheduled);
      vm.setFilter(VoucherFilter.live);
      expect(vm.visible, hasLength(1), reason: 'scheduled ones are listed with the live ones');
      vm.dispose();
    });

    test('adding a voucher saves it with its audit line; a taken code and a failed write change nothing', () async {
      final audit = FakeAuditLog();
      final repo = FakeAdminVoucherRepository(audit);
      final vm = makeVm(repo);
      await pumpEventQueue();

      expect((await vm.save.execute((form: _fixed(), isNew: true)))!.isOk, isTrue);
      expect(repo.byCode('NEW10K').discount, isA<FixedDiscount>());
      expect(audit.entries.single.action, AuditAction.voucherSave);

      final taken = await vm.save.execute((form: _fixed(code: 'BBSTUDENT'), isNew: true));
      expect((taken! as Err<void>).error.message, contains('đã có'));
      repo.failNext = const NetworkException();
      final offline = await vm.save.execute((form: _fixed(code: 'OTHER'), isNew: true));
      expect((offline! as Err<void>).error, isA<NetworkException>());
      expect(repo.vouchers.where((v) => v.code == 'OTHER'), isEmpty);
      expect(audit.entries, hasLength(1));
      vm.dispose();
    });

    test('editing changes the values and keeps the code; a wrong value is refused before it is sent', () async {
      final repo = FakeAdminVoucherRepository(FakeAuditLog());
      final vm = makeVm(repo);
      await pumpEventQueue();

      final form = VoucherForm.of(repo.byCode('BBSTUDENT'))
          .copyWith(amount: '12000', activeFrom: '10:00', activeTo: '11:00');
      expect((await vm.save.execute((form: form, isNew: false)))!.isOk, isTrue);
      final saved = repo.byCode('BBSTUDENT');
      expect((saved.discount as FixedDiscount).amountVnd, 12000);
      expect((saved.activeFrom, saved.activeTo), ('10:00', '11:00'));

      final bad = await vm.save.execute((form: form.copyWith(amount: '0'), isNew: false));
      expect((bad! as Err<void>).error.message, contains('lớn hơn 0'));
      expect(vm.problemOf(const VoucherForm(code: 'ABC', title: 'T', amount: '5'), isNew: true), 'Chọn ngày hết hạn.');
      vm.dispose();
    });
  });

  group('A04 on screen', () {
    Future<FakeAdminVoucherRepository> open(WidgetTester tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1400, 1000);
      addTearDown(tester.view.reset);
      final deps = await pumpSystemApp(tester);
      await goToPage(tester, 'Voucher');
      return deps.vouchers;
    }

    testWidgets('lists the codes with their state, and the filter narrows them', (tester) async {
      await open(tester);
      expect(byId('a04.row.BBSTUDENT'), findsOneWidget);
      expect(byId('a04.row.OLD2020'), findsOneWidget);
      expect(find.text('Hết hạn'), findsWidgets);

      await tester.tap(byId('a04.filter.expired'));
      await tester.pumpAndSettle();
      expect(byId('a04.row.OLD2020'), findsOneWidget);
      expect(byId('a04.row.BBSTUDENT'), findsNothing);
    });

    testWidgets('the switch turns a code off at once, with its audit line', (tester) async {
      final repo = await open(tester);
      await tester.tap(byId('a04.switch.BBSTUDENT'));
      await tester.pumpAndSettle();
      expect(repo.byCode('BBSTUDENT').active, isFalse);
      expect(repo.audit.entries.single.summary, contains('Tắt'));
      expect(find.text('Đã tắt'), findsWidgets);
    });

    testWidgets('a new code is made in the dialog: kind, amount, a last day from the picker', (tester) async {
      final repo = await open(tester);
      await tester.tap(byId('a04.add'));
      await tester.pumpAndSettle();
      await tester.enterText(field('a04.code'), 'tet2027');
      await tester.enterText(field('a04.title'), 'Giảm Tết');
      await tester.enterText(field('a04.amount'), '8000');
      await tester.tap(byId('a04.save'));
      await tester.pumpAndSettle();
      expect(byId('a04.error'), findsOneWidget, reason: 'no last day yet');
      expect(find.text('Chọn ngày hết hạn.'), findsOneWidget);

      await tester.tap(byId('a04.expiresOn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(byId('a04.save'));
      await tester.pumpAndSettle();

      final voucher = repo.byCode('TET2027');
      expect(voucher.title, 'Giảm Tết');
      expect((voucher.discount as FixedDiscount).amountVnd, 8000);
      expect(byId('a04.row.TET2027'), findsOneWidget);
    });

    testWidgets('a percentage code asks for its cap', (tester) async {
      await open(tester);
      await tester.tap(byId('a04.add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giảm phần trăm'));
      await tester.pumpAndSettle();
      expect(byId('a04.percent'), findsOneWidget);
      expect(byId('a04.max'), findsOneWidget);
      expect(byId('a04.amount'), findsNothing);
    });
  });
}
