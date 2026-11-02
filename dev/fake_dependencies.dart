import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/domain/models/models.dart';

import 'fakes/fakes.dart';

AppDependencies createFakeDependencies({UserRole role = UserRole.user, bool signedIn = false}) {
  final menu = FakeMenuRepository();
  final cart = FakeCartRepository();
  return AppDependencies(
    auth: FakeAuthService(role: role, signedIn: signedIn),
    analytics: FakeAnalyticsService(),
    crash: FakeCrashService(),
    messaging: FakeMessagingService(),
    storage: FakeStorageService(),
    remoteConfig: FakeRemoteConfigService(),
    reportFiles: FakeReportFileService(),
    menu: menu,
    cart: cart,
    orders: FakeOrderRepository(cart: cart, voucherLookup: menu.getVoucher),
    reports: FakeReportRepository(),
    session: InMemorySessionRepository(),
    users: FakeUserRepository(),
    vouchers: FakeVoucherRepository(),
    slots: FakeSlotRepository(),
    incidents: FakeIncidentRepository(),
    reviews: FakeReviewRepository(),
  );
}
