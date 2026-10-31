import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/domain/models/models.dart';

import 'fakes/fakes.dart';

AppDependencies createFakeDependencies({UserRole role = UserRole.user, bool signedIn = false}) => AppDependencies(
  auth: FakeAuthService(role: role, signedIn: signedIn),
  analytics: FakeAnalyticsService(),
  crash: FakeCrashService(),
  messaging: FakeMessagingService(),
  storage: FakeStorageService(),
  remoteConfig: FakeRemoteConfigService(),
  menu: FakeMenuRepository(),
  cart: FakeCartRepository(),
  orders: FakeOrderRepository(),
);
