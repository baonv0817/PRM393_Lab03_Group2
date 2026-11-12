import 'package:breakbite_admin/ui/announcements/view_models/announcements_view_model.dart';
import 'package:breakbite_admin/ui/dashboard/view_models/dashboard_view_model.dart';
import 'package:breakbite_admin/ui/menu_management/view_models/menu_management_view_model.dart';
import 'package:breakbite_admin/ui/review_queue/view_models/review_queue_view_model.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('W01 sign-in (AdminSession)', () {
    test('staff with a kiosk get in and work on their own kiosk', () async {
      final auth = FakeAuthService();
      final session = AdminSession(auth: auth, menu: FakeMenuRepository());
      expect(session.ready, isFalse, reason: 'the router waits for the first auth event');
      auth.emit(staff);
      await settle();
      expect(session.signedIn, isTrue);
      expect(session.kioskId, 'k1');
      expect(session.rejection, isNull);
    });

    test('a customer account is signed out with the reason (reject non-staff)', () async {
      final auth = FakeAuthService(nextUser: customer);
      final session = AdminSession(auth: auth, menu: FakeMenuRepository());
      final result = await session.signIn.execute();
      await settle();
      expect(result, isA<Err<AppUser>>());
      expect(session.signedIn, isFalse);
      expect(auth.signOuts, 1);
      expect(session.rejection, contains('tài khoản khách hàng'));
    });

    test('staff without a kiosk are turned away too', () async {
      final auth = FakeAuthService(nextUser: staffWithoutKiosk);
      final session = AdminSession(auth: auth, menu: FakeMenuRepository());
      await session.signIn.execute();
      await settle();
      expect(session.signedIn, isFalse);
      expect(session.rejection, contains('chưa được gán kiosk'));
    });

    test('an admin picks the kiosk; the first one is the default', () async {
      final auth = FakeAuthService();
      final menu = FakeMenuRepository();
      final session = AdminSession(auth: auth, menu: menu);
      auth.emit(admin);
      await settle();
      menu.kiosks.add(const [
        Kiosk(id: 'q9-t2', name: 'Kiosk Q9 · Tầng 2', open: true, waitMinutes: 5),
        Kiosk(id: 'q9-t4', name: 'Kiosk Q9 · Tầng 4', open: true, waitMinutes: 5),
      ]);
      await settle();
      expect(session.kioskId, 'q9-t2');
      session.selectKiosk('q9-t4');
      expect(session.kioskId, 'q9-t4');
      expect(session.kioskName, 'Kiosk Q9 · Tầng 4');
    });
  });

  group('W03 review queue', () {
    test('shows pending orders oldest first and counts the ones in progress', () async {
      final orders = FakeOrderRepository();
      final vm = ReviewQueueViewModel(orders: orders, kioskId: 'k1');
      expect(vm.state, isA<ViewLoading<List<Order>>>());
      orders.queue.add([
        order('2', createdAt: DateTime(2026, 11, 12, 9, 40)),
        order('1', createdAt: DateTime(2026, 11, 12, 9, 20)),
        order('3', status: OrderStatus.preparing),
      ]);
      await settle();
      expect(vm.state.dataOrNull!.map((o) => o.id), ['1', '2']);
      expect(vm.inProgressCount, 1);
      expect(vm.selected!.id, '1', reason: 'the first order is selected by default');
    });

    test('approve sends the chosen time; reject sends the reason', () async {
      final orders = FakeOrderRepository();
      final vm = ReviewQueueViewModel(orders: orders, kioskId: 'k1');
      orders.queue.add([order('1'), order('2', createdAt: DateTime(2026, 11, 12, 10))]);
      await settle();
      await vm.approve.execute(const Duration(minutes: 15));
      vm.select(vm.state.dataOrNull![1]);
      await vm.reject.execute('Hết nguyên liệu');
      expect(orders.accepted, [('1', const Duration(minutes: 15))]);
      expect(orders.rejected, [('2', 'Hết nguyên liệu')]);
    });

    test('empty and error states', () async {
      final orders = FakeOrderRepository();
      final vm = ReviewQueueViewModel(orders: orders, kioskId: 'k1');
      orders.queue.add([order('9', status: OrderStatus.ready)]);
      await settle();
      expect(vm.state, isA<ViewEmpty<List<Order>>>());
      orders.queue.addError(const PermissionDeniedException());
      await settle();
      expect(vm.state, isA<ViewError<List<Order>>>());
    });
  });

  group('W02 menu management', () {
    test('reads archived items too, filters by chip and searches without diacritics', () async {
      final menu = FakeMenuRepository();
      final vm = MenuManagementViewModel(menu: menu, kioskId: 'k1');
      expect(menu.lastIncludeArchived, isTrue);
      menu.menu.add([
        item('tra-dao', name: 'Trà Đào'),
        item('banh-mi', name: 'Bánh mì', soldOut: true),
        item('mi-tron', name: 'Mì trộn', archived: true),
      ]);
      await settle();
      expect(vm.state.dataOrNull!.map((i) => i.dishId), ['tra-dao']);
      expect(vm.counts, {MenuFilter.onSale: 1, MenuFilter.soldOut: 1, MenuFilter.archived: 1, MenuFilter.all: 3});
      vm.setFilter(MenuFilter.all);
      vm.setQuery('banh');
      expect(vm.state.dataOrNull!.map((i) => i.dishId), ['banh-mi']);
      vm.setQuery('pho');
      expect(vm.state, isA<ViewEmpty<List<MenuItem>>>());
    });

    test('archive and restore flip the flag; save keeps the kiosk and the archived state', () async {
      final menu = FakeMenuRepository();
      final vm = MenuManagementViewModel(menu: menu, kioskId: 'k1');
      final archived = item('mi-tron', archived: true);
      await vm.toggleArchived.execute(item('tra-dao'));
      await vm.toggleArchived.execute(archived);
      expect(menu.archived, [('k1-tra-dao', true), ('k1-mi-tron', false)]);

      const input = MenuItemInput(name: ' Cà phê ', priceVnd: 18000, category: ItemCategory.drink, prepMinutes: 2);
      final created = await vm.save.execute((null, input));
      expect(created, isA<Ok<String>>());
      expect(menu.saved.single.kioskId, 'k1');
      expect(menu.saved.single.name, 'Cà phê');
      expect(menu.saved.single.id, isEmpty, reason: 'a new item has no id yet');

      await vm.save.execute((archived, input));
      expect(menu.saved.last.archived, isTrue, reason: 'editing an archived item does not bring it back');
    });

    test('a validation error from the repository reaches the dialog', () async {
      final vm = MenuManagementViewModel(menu: FakeMenuRepository(), kioskId: 'k1');
      const input = MenuItemInput(name: '', priceVnd: 1, category: ItemCategory.food, prepMinutes: 1);
      final result = await vm.save.execute((null, input));
      expect(result?.errorOrNull?.message, 'Nhập tên món.');
    });
  });

  group('W04 dashboard', () {
    test('shows the aggregation figures, or empty when the kiosk had no order', () async {
      final orders = FakeOrderRepository();
      final vm = DashboardViewModel(orders: orders, kioskId: 'k1', clock: () => DateTime(2026, 11, 12, 15));
      await settle();
      expect(vm.state, isA<ViewEmpty<KioskStats>>());
      expect(orders.statsSince, DateTime(2026, 11, 12));

      orders.stats = const Result.ok(
        KioskStats(deliveredCount: 12, revenueVnd: 468000, cancelledCount: 1, activeCount: 2),
      );
      vm.setPeriod(DashboardPeriod.week);
      await settle();
      expect(orders.statsSince, DateTime(2026, 11, 6), reason: 'the last seven days include today');
      expect(vm.state.dataOrNull!.revenueVnd, 468000);
    });

    test('an error offers a retry', () async {
      final orders = FakeOrderRepository()..stats = const Result.error(NetworkException());
      final vm = DashboardViewModel(orders: orders, kioskId: 'k1');
      await settle();
      expect(vm.state, isA<ViewError<KioskStats>>());
    });
  });

  group('W05 announcements', () {
    test('an admin publishes; the author is the signed-in admin', () async {
      final repo = FakeAnnouncementRepository();
      final vm = AnnouncementsViewModel(announcements: repo, uid: 'a1', canWrite: true);
      await vm.submit.execute(
        const AnnouncementInput(title: 'Nghỉ lễ', body: 'Kiosk nghỉ 2/9', publish: true, kioskId: 'k1'),
      );
      expect(repo.created.single, (
        title: 'Nghỉ lễ',
        body: 'Kiosk nghỉ 2/9',
        createdBy: 'a1',
        publish: true,
        kioskId: 'k1',
      ));
    });

    test('staff only read the published list and cannot submit', () async {
      final repo = FakeAnnouncementRepository();
      final vm = AnnouncementsViewModel(announcements: repo, uid: 's1', canWrite: false);
      repo.published.add(const []);
      await settle();
      expect(vm.state, isA<ViewEmpty<List<Announcement>>>());
      final result = await vm.submit.execute(const AnnouncementInput(title: 't', body: 'b', publish: true));
      expect(result?.errorOrNull, isA<PermissionDeniedException>());
      expect(repo.created, isEmpty);
    });

    test('the form checks the same limits as the rules', () {
      final vm = AnnouncementsViewModel(announcements: FakeAnnouncementRepository(), uid: 'a1', canWrite: true);
      expect(vm.problemWith('', 'b'), 'Nhập tiêu đề thông báo.');
      expect(vm.problemWith('x' * 121, 'b'), contains('120'));
      expect(vm.problemWith('t', ''), 'Nhập nội dung thông báo.');
      expect(vm.problemWith('t', 'b'), isNull);
    });
  });
}
