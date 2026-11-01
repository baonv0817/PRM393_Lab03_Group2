import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/domain/models/models.dart';

import 'fakes/fakes.dart';

AppDependencies createFakeDependencies({UserRole role = UserRole.user, bool signedIn = false}) => AppDependencies(
  auth: FakeAuthService(role: role, signedIn: signedIn),
  analytics: FakeAnalyticsService(),
  crash: FakeCrashService(),
  messaging: FakeMessagingService(),
  storage: FakeStorageService(),
  remoteConfig: FakeRemoteConfigService(),
  reportFiles: FakeReportFileService(),
  menu: FakeMenuRepository(),
  cart: FakeCartRepository(),
  orders: FakeOrderRepository(),
  reports: FakeReportRepository(),
  session: InMemorySessionRepository(),
  users: FakeUserRepository(),
);
