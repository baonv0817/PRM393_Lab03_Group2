import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_admin/ui/system/audit/view_models/admin_audit_view_model.dart';
import 'package:breakbite_admin/ui/system/audit/widgets/admin_audit_screen.dart';
import 'package:breakbite_admin/ui/system/incidents/view_models/admin_incidents_view_model.dart';
import 'package:breakbite_admin/ui/system/incidents/widgets/admin_incidents_screen.dart';
import 'package:breakbite_admin/ui/system/kiosks/view_models/admin_kiosks_view_model.dart';
import 'package:breakbite_admin/ui/system/kiosks/widgets/admin_kiosks_screen.dart';
import 'package:breakbite_admin/ui/system/orders/view_models/admin_orders_view_model.dart';
import 'package:breakbite_admin/ui/system/orders/widgets/admin_orders_screen.dart';
import 'package:breakbite_admin/ui/system/slots/view_models/admin_slots_view_model.dart';
import 'package:breakbite_admin/ui/system/slots/widgets/admin_slots_screen.dart';
import 'package:breakbite_admin/ui/system/stats/view_models/admin_stats_view_model.dart';
import 'package:breakbite_admin/ui/system/stats/widgets/admin_stats_screen.dart';
import 'package:breakbite_admin/ui/system/users/view_models/admin_users_view_model.dart';
import 'package:breakbite_admin/ui/system/users/widgets/admin_users_screen.dart';
import 'package:breakbite_admin/ui/system/vouchers/view_models/admin_vouchers_view_model.dart';
import 'package:breakbite_admin/ui/system/vouchers/widgets/admin_vouchers_screen.dart';
import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/data/services/remote_config_service.dart';
import 'package:breakbite_core/data/services/stats_insight_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Paths of the system administration pages: only an admin reaches them (the router turns staff away), and the
/// Security Rules let only an admin write what they change.
abstract final class SystemRoutes {
  static const prefix = '/system';
  static const users = '/system/users';
  static const kiosks = '/system/kiosks';
  static const slots = '/system/slots';
  static const vouchers = '/system/vouchers';
  static const orders = '/system/orders';
  static const incidents = '/system/incidents';
  static const stats = '/system/stats';
  static const audit = '/system/audit';

  /// The rail entries of an admin after the kiosk pages, in order.
  static const tabs = [users, kiosks, slots, vouchers, orders, incidents, stats, audit];
}

/// Instant page transition for snappy web performance.
Page<void> _fade(GoRouterState state, Widget child) => NoTransitionPage<void>(
  key: state.pageKey,
  child: child,
);

/// The system pages, to be placed inside the shell route.
final List<RouteBase> systemPages = [
  GoRoute(
    path: SystemRoutes.users,
    pageBuilder: (context, state) => _fade(
      state,
      ChangeNotifierProvider(
        create: (_) => AdminUsersViewModel(
          users: context.read<AdminUserRepository>(),
          menu: context.read<MenuRepository>(),
          selfUid: context.read<AdminSession>().user?.uid ?? '',
        ),
        child: const AdminUsersScreen(),
      ),
    ),
  ),
  GoRoute(
    path: SystemRoutes.kiosks,
    pageBuilder: (context, state) => _fade(
      state,
      ChangeNotifierProvider(
        create: (_) =>
            AdminKiosksViewModel(menu: context.read<MenuRepository>(), kiosks: context.read<AdminKioskRepository>()),
        child: const AdminKiosksScreen(),
      ),
    ),
  ),
  GoRoute(
    path: SystemRoutes.slots,
    pageBuilder: (context, state) => _fade(
      state,
      ChangeNotifierProvider(
        create: (_) =>
            AdminSlotsViewModel(menu: context.read<MenuRepository>(), slots: context.read<AdminSlotRepository>()),
        child: const AdminSlotsScreen(),
      ),
    ),
  ),
  GoRoute(
    path: SystemRoutes.vouchers,
    pageBuilder: (context, state) => _fade(
      state,
      ChangeNotifierProvider(
        create: (_) => AdminVouchersViewModel(vouchers: context.read<AdminVoucherRepository>()),
        child: const AdminVouchersScreen(),
      ),
    ),
  ),
  GoRoute(
    path: SystemRoutes.orders,
    pageBuilder: (context, state) => _fade(
      state,
      ChangeNotifierProvider(
        create: (_) =>
            AdminOrdersViewModel(orders: context.read<AdminOrderRepository>(), menu: context.read<MenuRepository>()),
        child: const AdminOrdersScreen(),
      ),
    ),
  ),
  GoRoute(
    path: SystemRoutes.incidents,
    pageBuilder: (context, state) => _fade(
      state,
      ChangeNotifierProvider(
        create: (_) => AdminIncidentsViewModel(
          incidents: context.read<AdminIncidentRepository>(),
          menu: context.read<MenuRepository>(),
        ),
        child: const AdminIncidentsScreen(),
      ),
    ),
  ),
  GoRoute(
    path: SystemRoutes.stats,
    pageBuilder: (context, state) => _fade(
      state,
      ChangeNotifierProvider(
        create: (_) => AdminStatsViewModel(
          orders: context.read<AdminOrderRepository>(),
          menu: context.read<MenuRepository>(),
          insightService: context.read<StatsInsightService?>(),
          remoteConfig: context.read<RemoteConfigService>(),
          analytics: context.read<AnalyticsService>(),
        ),
        child: const AdminStatsScreen(),
      ),
    ),
  ),
  GoRoute(
    path: SystemRoutes.audit,
    pageBuilder: (context, state) => _fade(
      state,
      ChangeNotifierProvider(
        create: (_) => AdminAuditViewModel(audit: context.read<AuditLogRepository>()),
        child: const AdminAuditScreen(),
      ),
    ),
  ),
];
