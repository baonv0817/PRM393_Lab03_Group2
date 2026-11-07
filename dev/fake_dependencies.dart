import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/domain/models/models.dart';

import 'fakes/fakes.dart';

/// [orderClock] is when the first order of the fake order repository is placed (a fixed morning by default, so
/// tests do not depend on today's date).
AppDependencies createFakeDependencies({UserRole role = UserRole.user, bool signedIn = false, DateTime? orderClock}) {
  final menu = FakeMenuRepository();
  final cart = FakeCartRepository();
  return AppDependencies(
    auth: FakeAuthService(role: role, signedIn: signedIn),
    analytics: FakeAnalyticsService(),
    crash: FakeCrashService(),
    connectivity: FakeConnectivityService(),
    messaging: FakeMessagingService(),
    reminders: FakeReminderService(),
    storage: FakeStorageService(),
    remoteConfig: FakeRemoteConfigService(),
    reportFiles: FakeReportFileService(),
    menu: menu,
    cart: cart,
    orders: FakeOrderRepository(cart: cart, voucherLookup: menu.getVoucher, startAt: orderClock),
    reports: FakeReportRepository(),
    session: InMemorySessionRepository(),
    users: FakeUserRepository(),
    vouchers: FakeVoucherRepository(),
    slots: FakeSlotRepository(),
    incidents: FakeIncidentRepository(),
    reviews: FakeReviewRepository(),
    favorites: FakeFavoriteRepository(),
    notifications: FakeNotificationRepository(),
  );
}
