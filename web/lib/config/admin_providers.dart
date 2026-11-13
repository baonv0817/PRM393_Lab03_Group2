import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/data/repositories/announcement_repository.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/data/services/auth_service.dart';
import 'package:breakbite_core/data/services/connectivity_service.dart';
import 'package:breakbite_core/data/services/remote_config_service.dart';
import 'package:breakbite_core/data/services/stats_insight_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// The providers of the web admin, apart from `dependencies.dart` (which needs the browser) so a test on the VM can
/// build the same tree with fakes.

/// What the system administration pages (an admin's users, kiosks, slots, vouchers, every order and incident, the
/// audit log) read and write.
class SystemRepositories {
  const SystemRepositories({
    required this.users,
    required this.kiosks,
    required this.slots,
    required this.vouchers,
    required this.orders,
    required this.incidents,
    required this.audit,
  });

  final AdminUserRepository users;
  final AdminKioskRepository kiosks;
  final AdminSlotRepository slots;
  final AdminVoucherRepository vouchers;
  final AdminOrderRepository orders;
  final AdminIncidentRepository incidents;
  final AuditLogRepository audit;
}

List<SingleChildWidget> adminProviders({
  required AuthService auth,
  required OrderRepository orders,
  required MenuRepository menu,
  required AnnouncementRepository announcements,
  required AnalyticsService analytics,
  required RemoteConfigService remoteConfig,
  required ConnectivityService connectivity,
  SystemRepositories? system,
  StatsInsightService? insight,
}) => [
  Provider<AuthService>.value(value: auth),
  Provider<OrderRepository>.value(value: orders),
  Provider<MenuRepository>.value(value: menu),
  Provider<AnnouncementRepository>.value(value: announcements),
  Provider<AnalyticsService>.value(value: analytics),
  Provider<RemoteConfigService>.value(value: remoteConfig),
  // `null` in a build without the AI summary: the statistics page then does not offer it.
  Provider<StatsInsightService?>.value(value: insight),
  if (system != null) ...[
    Provider<AdminUserRepository>.value(value: system.users),
    Provider<AdminKioskRepository>.value(value: system.kiosks),
    Provider<AdminSlotRepository>.value(value: system.slots),
    Provider<AdminVoucherRepository>.value(value: system.vouchers),
    Provider<AdminOrderRepository>.value(value: system.orders),
    Provider<AdminIncidentRepository>.value(value: system.incidents),
    Provider<AuditLogRepository>.value(value: system.audit),
  ],
  ChangeNotifierProvider<AdminSession>(
    create: (_) => AdminSession(auth: auth, menu: menu, analytics: analytics, connectivity: connectivity),
  ),
];
