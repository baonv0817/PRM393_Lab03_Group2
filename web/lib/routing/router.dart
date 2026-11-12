import 'package:breakbite_admin/ui/announcements/widgets/announcements_screen.dart';
import 'package:breakbite_admin/ui/auth/widgets/sign_in_screen.dart';
import 'package:breakbite_admin/ui/dashboard/widgets/dashboard_screen.dart';
import 'package:breakbite_admin/ui/menu_management/widgets/menu_management_screen.dart';
import 'package:breakbite_admin/ui/review_queue/widgets/review_queue_screen.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_admin/ui/shell/widgets/admin_shell.dart';
import 'package:breakbite_core/ui/core/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract final class AdminRoutes {
  static const loading = '/loading';
  static const signIn = '/sign-in';
  static const review = '/review';
  static const menu = '/menu';
  static const dashboard = '/dashboard';
  static const announcements = '/announcements';

  /// The rail, in order.
  static const tabs = [review, menu, dashboard, announcements];
}

/// Signed-out visitors only reach the sign-in screen; a signed-in staff member or admin never sees it.
GoRouter buildRouter(AdminSession session) => GoRouter(
  initialLocation: AdminRoutes.review,
  refreshListenable: session,
  redirect: (context, state) {
    final at = state.matchedLocation;
    if (!session.ready) return at == AdminRoutes.loading ? null : AdminRoutes.loading;
    if (!session.signedIn) return at == AdminRoutes.signIn ? null : AdminRoutes.signIn;
    if (at == AdminRoutes.signIn || at == AdminRoutes.loading) return AdminRoutes.review;
    return null;
  },
  routes: [
    GoRoute(
      path: AdminRoutes.loading,
      builder: (_, _) => const Scaffold(body: LoadingView(message: 'Đang kiểm tra đăng nhập…')),
    ),
    GoRoute(path: AdminRoutes.signIn, builder: (_, _) => const SignInScreen()),
    ShellRoute(
      builder: (context, state, child) => AdminShell(location: state.matchedLocation, child: child),
      routes: [
        GoRoute(
          path: AdminRoutes.review,
          pageBuilder: (_, _) => const NoTransitionPage(child: ReviewQueueScreen()),
        ),
        GoRoute(
          path: AdminRoutes.menu,
          pageBuilder: (_, _) => const NoTransitionPage(child: MenuManagementScreen()),
        ),
        GoRoute(
          path: AdminRoutes.dashboard,
          pageBuilder: (_, _) => const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: AdminRoutes.announcements,
          pageBuilder: (_, _) => const NoTransitionPage(child: AnnouncementsScreen()),
        ),
      ],
    ),
  ],
);
