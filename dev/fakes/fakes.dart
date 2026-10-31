/// Bản giả trong bộ nhớ của mọi service và repository, dùng cho `dev/main_dev.dart` và cho test.
/// Nằm ngoài `lib/` nên không bao giờ có trong bản build nộp (handout cấm dữ liệu giả trong bản nộp).
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
