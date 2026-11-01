import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class AppDependencies {
  const AppDependencies({
    required this.auth,
    required this.analytics,
    required this.crash,
    required this.messaging,
    required this.storage,
    required this.remoteConfig,
    required this.reportFiles,
    required this.menu,
    required this.cart,
    required this.orders,
    required this.reports,
    required this.session,
  });

  final AuthService auth;
  final AnalyticsService analytics;
  final CrashService crash;
  final MessagingService messaging;
  final StorageService storage;
  final RemoteConfigService remoteConfig;
  final ReportFileService reportFiles;

  final MenuRepository menu;
  final CartRepository cart;
  final OrderRepository orders;
  final ReportRepository reports;
  final SessionRepository session;
  List<SingleChildWidget> get providers => [
    Provider<AuthService>.value(value: auth),
    Provider<AnalyticsService>.value(value: analytics),
    Provider<CrashService>.value(value: crash),
    Provider<MessagingService>.value(value: messaging),
    Provider<StorageService>.value(value: storage),
    Provider<RemoteConfigService>.value(value: remoteConfig),
    Provider<ReportFileService>.value(value: reportFiles),
    Provider<MenuRepository>.value(value: menu),
    Provider<CartRepository>.value(value: cart),
    Provider<OrderRepository>.value(value: orders),
    Provider<ReportRepository>.value(value: reports),
    Provider<SessionRepository>.value(value: session),
  ];
}
