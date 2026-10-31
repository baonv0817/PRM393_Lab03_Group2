import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// All of the app's services and repositories, built once: the Firebase version is in `firebase_dependencies.dart`,
/// the fake version in `dev/fake_dependencies.dart`. To add a repository: one field here, one line in
/// [providers], and one line in each place that builds it.
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

  /// Provides each part separately so a route reads only what it needs: `context.read<MenuRepository>()`.
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
