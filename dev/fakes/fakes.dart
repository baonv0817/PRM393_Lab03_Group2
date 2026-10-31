/// In-memory fakes of every service and repository, used by `dev/main_dev.dart` and by tests.
/// They live outside `lib/`, so they never ship in the submitted build (the handout forbids fake data there).
library;

export 'fake_analytics_service.dart';
export 'fake_auth_service.dart';
export 'fake_cart_repository.dart';
export 'fake_crash_service.dart';
export 'fake_menu_repository.dart';
export 'fake_messaging_service.dart';
export 'fake_order_repository.dart';
export 'fake_remote_config_service.dart';
export 'fake_storage_service.dart';
export 'live_value.dart';
