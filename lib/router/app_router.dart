import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/widgets.dart';
import 'routes_p1.dart';
import 'routes_p2.dart';
import 'routes_p3.dart';
import 'routes_p4.dart';

const _customerTabs = [
  AppNavTab(label: 'Trang chủ', icon: Icons.home_outlined),
  AppNavTab(label: 'Thực đơn', icon: Icons.restaurant_menu),
  AppNavTab(label: 'Đơn hàng', icon: Icons.receipt_long_outlined),
  AppNavTab(label: 'Cá nhân', icon: Icons.person_outline),
];

const _sellerTabs = [
  AppNavTab(label: 'Đơn', icon: Icons.receipt_long_outlined),
  AppNavTab(label: 'Quét mã', icon: Icons.qr_code_scanner),
  AppNavTab(label: 'Món', icon: Icons.restaurant_menu),
  AppNavTab(label: 'Quán', icon: Icons.storefront_outlined),
];

const _publicPaths = {'/sign-in', '/seller/sign-in'};

/// Quyết định điều hướng theo trạng thái đăng nhập và vai trò (tách ra để test).
String? authRedirect({required AppUser? user, required bool initialized, required String location}) {
  if (!initialized) return null;
  final isSeller = location.startsWith('/seller');
  final isPublic = _publicPaths.contains(location);
  if (user == null) {
    return isPublic ? null : (isSeller ? '/seller/sign-in' : '/sign-in');
  }
  if (isPublic) return user.isStaff ? '/seller/orders' : '/home';
  // Đúng vai trò: khách không vào được vùng người bán; nhân viên dùng app người bán.
  if (isSeller && !user.isStaff) return '/home';
  if (!isSeller && user.isStaff) return '/seller/orders';
  return null;
}

/// Router của app. Mỗi người phụ trách sửa file `routes_pX.dart` của mình, không sửa file này.
GoRouter createRouter(AuthViewModel auth) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (context, state) => authRedirect(
      user: auth.user,
      initialized: auth.initialized,
      location: state.matchedLocation,
    ),
    routes: [
      // Route cụ thể đứng trước route có tham số.
      ...p2Routes,
      ...p1Routes,
      ...p3Routes,
      ...p4Routes,
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
