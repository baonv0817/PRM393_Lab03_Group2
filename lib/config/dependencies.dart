import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../data/repositories/repositories.dart';
import '../data/services/services.dart';

/// Mọi service và repository của app, dựng một lần: bản Firebase ở `firebase_dependencies.dart`,
/// bản giả ở `dev/fake_dependencies.dart`. Thêm repository mới: một field ở đây, một dòng trong
/// [providers], một dòng ở mỗi nơi dựng.
class AppDependencies {
  const AppDependencies({
    required this.auth,
    required this.analytics,
    required this.crash,
    required this.messaging,
    required this.storage,
    required this.remoteConfig,
    required this.menu,
    required this.cart,
    required this.orders,
  });

  final AuthService auth;
  final AnalyticsService analytics;
  final CrashService crash;
  final MessagingService messaging;
  final StorageService storage;
  final RemoteConfigService remoteConfig;

  final MenuRepository menu;
  final CartRepository cart;
  final OrderRepository orders;

  /// Cung cấp từng phần riêng để route chỉ đọc đúng thứ cần: `context.read<MenuRepository>()`.
  List<SingleChildWidget> get providers => [
    Provider<AuthService>.value(value: auth),
    Provider<AnalyticsService>.value(value: analytics),
    Provider<CrashService>.value(value: crash),
    Provider<MessagingService>.value(value: messaging),
    Provider<StorageService>.value(value: storage),
    Provider<RemoteConfigService>.value(value: remoteConfig),
    Provider<MenuRepository>.value(value: menu),
    Provider<CartRepository>.value(value: cart),
    Provider<OrderRepository>.value(value: orders),
  ];
}
