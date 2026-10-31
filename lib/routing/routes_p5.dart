import 'package:breakbite/routing/route_helpers.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:go_router/go_router.dart';

// P5: favorites S13, notification settings S18, notifications S19, search S28
// (S14 is a bottom sheet and S30 is an app-wide state, so neither has a route).

/// Full-screen routes of P5.
final List<GoRoute> p5Routes = [
  placeholderRoute(AppRoutes.favorites, 'S13', 'Món yêu thích', 'P5'),
  placeholderRoute(AppRoutes.notifications, 'S19', 'Thông báo', 'P5'),
  placeholderRoute(AppRoutes.profileNotifications, 'S18', 'Cài đặt thông báo', 'P5'),
  placeholderRoute(AppRoutes.search, 'S28', 'Tìm kiếm', 'P5'),
];
