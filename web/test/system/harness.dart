import 'package:breakbite_admin/app.dart';
import 'package:breakbite_admin/config/admin_providers.dart';
import 'package:breakbite_admin/routing/system_pages.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../fakes.dart' as web;
import 'fake_menu_repository.dart';
import 'fakes/system_fakes.dart';

/// The admin an opened site is signed in as: the id and name the fakes of the system pages mark as "bạn".
const systemAdmin = AppUser(
  uid: 'dev-admin',
  displayName: 'Quản trị viên',
  role: UserRole.admin,
  email: 'admin@breakbite.dev',
);

/// The fakes behind the system pages of an opened site, to check what a screen wrote.
class SystemDeps {
  SystemDeps() : audit = FakeAuditLog(), menu = FakeMenuRepository() {
    users = FakeAdminUserRepository(audit);
    kiosks = FakeAdminKioskRepository(menu, audit);
    slots = FakeAdminSlotRepository(audit);
    vouchers = FakeAdminVoucherRepository(audit);
    orders = FakeAdminOrderRepository();
    incidents = FakeAdminIncidentRepository();
  }

  final FakeAuditLog audit;
  final FakeMenuRepository menu;
  late final FakeAdminUserRepository users;
  late final FakeAdminKioskRepository kiosks;
  late final FakeAdminSlotRepository slots;
  late final FakeAdminVoucherRepository vouchers;
  late final FakeAdminOrderRepository orders;
  late final FakeAdminIncidentRepository incidents;

  SystemRepositories get repositories => SystemRepositories(
    users: users,
    kiosks: kiosks,
    slots: slots,
    vouchers: vouchers,
    orders: orders,
    incidents: incidents,
    audit: audit,
  );
}

/// Opens the whole web admin on fake data, signed in as [as], and waits until it has settled.
Future<SystemDeps> pumpSystemApp(WidgetTester tester, {AppUser as = systemAdmin}) async {
  final deps = SystemDeps();
  final auth = web.FakeAuthService(nextUser: as);
  final queue = web.FakeOrderRepository();
  final providers = adminProviders(
    auth: auth,
    orders: queue,
    menu: deps.menu,
    announcements: web.FakeAnnouncementRepository(),
    analytics: web.FakeAnalytics(),
    remoteConfig: web.FakeRemoteConfig(),
    connectivity: web.FakeConnectivity(),
    system: deps.repositories,
  );
  await tester.pumpWidget(MultiProvider(providers: providers, child: const AdminApp()));
  auth.emit(as);
  // The site opens on the review queue; an empty queue lets it settle instead of waiting for orders.
  await tester.pump(const Duration(milliseconds: 100));
  queue.queue.add(const []);
  await tester.pumpAndSettle();
  return deps;
}

const _pages = {
  'Người dùng': SystemRoutes.users,
  'Kiosk': SystemRoutes.kiosks,
  'Khung giờ': SystemRoutes.slots,
  'Voucher': SystemRoutes.vouchers,
  'Đơn hàng': SystemRoutes.orders,
  'Sự cố': SystemRoutes.incidents,
  'Thống kê': SystemRoutes.stats,
  'Nhật ký': SystemRoutes.audit,
};

/// Goes to a system page by the name it had in the side menu of the first admin site.
Future<void> goToPage(WidgetTester tester, String page) async {
  final route = _pages[page];
  if (route == null) throw ArgumentError('No system page called "$page"');
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
  await tester.pumpAndSettle();
}
