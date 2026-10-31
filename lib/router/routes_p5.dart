import 'package:go_router/go_router.dart';

import 'route_helpers.dart';

// P5: favorites S13, notification settings S18, notifications S19, search S28
// (S14 is a bottom sheet and S30 is an app-wide state, so neither has a route).

/// Full-screen routes of P5.
final List<GoRoute> p5Routes = [
  placeholderRoute('/favorites', 'S13', 'Món yêu thích', 'P5'),
  placeholderRoute('/notifications', 'S19', 'Thông báo', 'P5'),
  placeholderRoute('/profile/notifications', 'S18', 'Cài đặt thông báo', 'P5'),
  placeholderRoute('/search', 'S28', 'Tìm kiếm', 'P5'),
];
