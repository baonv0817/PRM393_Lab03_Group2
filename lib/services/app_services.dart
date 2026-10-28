import 'services.dart';

/// Gói mọi service để inject một lần bằng `Provider<AppServices>`.
/// ViewModel nhận từng service cần dùng qua constructor, không giữ cả gói.
class AppServices {
  const AppServices({
    required this.auth,
    required this.menu,
    required this.cart,
    required this.orders,
    required this.storage,
    required this.messaging,
    required this.analytics,
    required this.crash,
    required this.remoteConfig,
  });

  final AuthService auth;
  final MenuService menu;
  final CartService cart;
  final OrderService orders;
  final StorageService storage;
  final MessagingService messaging;
  final AnalyticsService analytics;
  final CrashService crash;
  final RemoteConfigService remoteConfig;
}
