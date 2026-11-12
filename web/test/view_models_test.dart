import 'package:breakbite_admin/ui/announcements/view_models/announcements_view_model.dart';
import 'package:breakbite_admin/ui/dashboard/view_models/dashboard_view_model.dart';
import 'package:breakbite_admin/ui/menu_management/view_models/menu_management_view_model.dart';
import 'package:breakbite_admin/ui/review_queue/view_models/review_queue_view_model.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_core/data/services/analytics_events.dart';
import 'package:breakbite_core/data/services/remote_config_service.dart';
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

    test('offline: the session says so live, and "Thử lại" asks the browser again', () async {
      final connectivity = FakeConnectivity();
      final session = AdminSession(auth: FakeAuthService(), menu: FakeMenuRepository(), connectivity: connectivity);
      expect(session.online, isTrue);
      var notified = 0;
      session.addListener(() => notified++);
      connectivity.set(false);
      await settle();
      expect(session.online, isFalse);
      expect(AdminSession.offlineMessage, contains('Mất kết nối mạng'));
      connectivity.online = true;
      await session.checkConnection();
      expect(session.online, isTrue);
      expect(notified, 2);
    });

    test('CR-F04: an admin sees "loading" until the kiosks arrive, and an error with a retry if they fail', () async {
      final auth = FakeAuthService(nextUser: admin);
      final menu = FakeMenuRepository();
      final session = AdminSession(auth: auth, menu: menu);
      auth.emit(admin);
      await settle();
      expect(session.kioskId, isNull);
      expect(session.kiosksLoaded, isFalse, reason: 'loading, not "there are no kiosks"');
      expect(session.kiosksError, isNull);

      menu.kiosks.addError(const PermissionDeniedException());
      await settle();
      expect(session.kiosksError, isNotNull);

      session.retryKiosks();
      expect(session.kiosksError, isNull);
      menu.kiosks.add(const [Kiosk(id: 'q9-t2', name: 'Kiosk Q9 · Tầng 2', open: true, waitMinutes: 5)]);
      await settle();
      expect(session.kiosksLoaded, isTrue);
      expect(session.kioskId, 'q9-t2');
    });

    test('a signed-in staff member logs admin_sign_in with the role; a rejected customer logs nothing', () async {
      final analytics = FakeAnalytics();
      final session = AdminSession(auth: FakeAuthService(), menu: FakeMenuRepository(), analytics: analytics);
      await session.signIn.execute();
      expect(analytics.paramsOf(AnalyticsEvents.adminSignIn), [
        {'role': 'staff'},
      ]);
      expect(analytics.userId, 's1');
      final other = FakeAnalytics();
      final rejected = AdminSession(
        auth: FakeAuthService(nextUser: customer),
        menu: FakeMenuRepository(),
        analytics: other,
      );
      await rejected.signIn.execute();
      expect(other.events, isEmpty);
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

    test('logs order_reviewed with the decision, never the reason text', () async {
      final orders = FakeOrderRepository();
      final analytics = FakeAnalytics();
      final vm = ReviewQueueViewModel(orders: orders, kioskId: 'k1', analytics: analytics);
      orders.queue.add([order('1'), order('2', createdAt: DateTime(2026, 11, 12, 10))]);
      await settle();
      await vm.approve.execute(const Duration(minutes: 10));
      vm.select(vm.state.dataOrNull![1]);
      await vm.reject.execute('Khách gọi huỷ');
      expect(analytics.paramsOf(AnalyticsEvents.orderReviewed), [
        {'decision': 'approved', 'ready_in_min': 10},
        {'decision': 'rejected', 'preset_reason': false},
      ]);
    });

    test('the reject reasons come from Remote Config and change live', () async {
      final config = FakeRemoteConfig({RemoteKeys.rejectReasons: 'Hết bánh| Hết bánh |  |Máy hỏng'});
      final vm = ReviewQueueViewModel(orders: FakeOrderRepository(), kioskId: 'k1', remoteConfig: config);
      expect(vm.rejectReasons, ['Hết bánh', 'Máy hỏng'], reason: 'trimmed, no empty or repeated entries');
      var notified = 0;
      vm.addListener(() => notified++);
      config.publish(RemoteKeys.rejectReasons, 'Quầy đóng sớm');
      await settle();
      expect(vm.rejectReasons, ['Quầy đóng sớm']);
      expect(notified, 1);
      config.publish(RemoteKeys.rejectReasons, ' | ');
      await settle();
      expect(vm.rejectReasons, RemoteKeys.defaultRejectReasons.split('|'), reason: 'an empty value keeps the defaults');
    });

    test('without Remote Config the in-app reasons are offered', () {
      final vm = ReviewQueueViewModel(orders: FakeOrderRepository(), kioskId: 'k1');
      expect(vm.rejectReasons, ['Hết nguyên liệu', 'Quầy sắp đóng cửa', 'Quá tải, không kịp làm', 'Đơn trùng']);
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

    test('logs menu_item_saved and menu_item_archived only when the write succeeds', () async {
      final analytics = FakeAnalytics();
      final vm = MenuManagementViewModel(menu: FakeMenuRepository(), kioskId: 'k1', analytics: analytics);
      const input = MenuItemInput(name: 'Cà phê', priceVnd: 18000, category: ItemCategory.drink, prepMinutes: 2);
      await vm.save.execute((null, input));
      await vm.save.execute((
        null,
        const MenuItemInput(name: '', priceVnd: 1, category: ItemCategory.food, prepMinutes: 1),
      ));
      await vm.toggleArchived.execute(item('tra-dao'));
      expect(analytics.paramsOf(AnalyticsEvents.menuItemSaved), [
        {'is_new': true, 'category': 'drink', 'sold_out': false},
      ]);
      expect(analytics.paramsOf(AnalyticsEvents.menuItemArchived), [
        {'archived': true},
      ]);
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

    test('logs announcement_saved with the audience, not the text', () async {
      final analytics = FakeAnalytics();
      final vm = AnnouncementsViewModel(
        announcements: FakeAnnouncementRepository(),
        uid: 'a1',
        canWrite: true,
        analytics: analytics,
      );
      await vm.submit.execute(const AnnouncementInput(title: 'Nghỉ lễ', body: 'Nghỉ 2/9', publish: true));
      await vm.submit.execute(const AnnouncementInput(title: 'Nháp', body: 'b', publish: false, kioskId: 'k1'));
      expect(analytics.paramsOf(AnalyticsEvents.announcementSaved), [
        {'published': true, 'audience': 'all'},
        {'published': false, 'audience': 'kiosk'},
      ]);
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
