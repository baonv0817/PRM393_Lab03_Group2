import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/routing/routes_p1.dart';
import 'package:breakbite/routing/routes_p2.dart';
import 'package:breakbite/routing/routes_p3.dart';
import 'package:breakbite/routing/routes_p4.dart';
import 'package:breakbite/routing/routes_p5.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _customerTabs = [
  AppNavTab(label: 'Trang chủ', icon: Icons.home),
  AppNavTab(label: 'Thực đơn', icon: Icons.restaurant),
  AppNavTab(label: 'Đơn hàng', icon: Icons.receipt),
  AppNavTab(label: 'Cá nhân', icon: Icons.person),
];

const _sellerTabs = [
  AppNavTab(label: 'Đơn', icon: Icons.receipt),
  AppNavTab(label: 'Quét mã', icon: Icons.qr_code_scanner),
  AppNavTab(label: 'Món', icon: Icons.restaurant),
  AppNavTab(label: 'Quán', icon: Icons.storefront),
];

const _publicPaths = {AppRoutes.signIn, AppRoutes.sellerSignIn};
const _onboardingPath = AppRoutes.onboarding;

String? authRedirect({
  required AppUser? user,
  required bool initialized,
  required String location,
  bool onboardingDone = true,
}) {
  if (!initialized) return location == AppRoutes.splash ? null : AppRoutes.splash;
  if (location == AppRoutes.splash) {
    if (user == null) return onboardingDone ? AppRoutes.signIn : _onboardingPath;
    return user.isStaff ? AppRoutes.sellerOrders : AppRoutes.home;
  }
  final isSeller = location.startsWith(AppRoutes.sellerPrefix);
  final isPublic = _publicPaths.contains(location);
  if (user == null) {
    if (isSeller) return isPublic ? null : AppRoutes.sellerSignIn;
    if (location == _onboardingPath) return onboardingDone ? AppRoutes.signIn : null;
    if (!onboardingDone) return _onboardingPath;
    return isPublic ? null : AppRoutes.signIn;
  }
  if (isPublic || location == _onboardingPath) return user.isStaff ? AppRoutes.sellerOrders : AppRoutes.home;
  if (isSeller && !user.isStaff) return AppRoutes.home;
  if (!isSeller && user.isStaff) return AppRoutes.sellerOrders;
  return null;
}

GoRouter createRouter(AuthViewModel auth) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: auth,
    redirect: (context, state) => authRedirect(
      user: auth.user,
      initialized: auth.initialized,
      location: state.matchedLocation,
      onboardingDone: auth.onboardingDone,
    ),
    routes: [
      ...p2Routes,
      ...p1Routes,
      ...p3Routes,
      ...p4Routes,
      ...p5Routes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell, tabs: _customerTabs),
        branches: [
          StatefulShellBranch(routes: [homeRoute]),
          StatefulShellBranch(routes: [menuRoute]),
          StatefulShellBranch(routes: [ordersRoute]),
          StatefulShellBranch(routes: [profileRoute]),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell, tabs: _sellerTabs),
        branches: [
          StatefulShellBranch(routes: [sellerOrdersRoute]),
          StatefulShellBranch(routes: [sellerScanRoute]),
          StatefulShellBranch(routes: [sellerMenuRoute]),
          StatefulShellBranch(routes: [sellerShopRoute]),
        ],
      ),
    ],
  );
}

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell, required this.tabs});

  final StatefulNavigationShell shell;
  final List<AppNavTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppNavBar(
        tabs: tabs,
        selectedIndex: shell.currentIndex,
        onSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
