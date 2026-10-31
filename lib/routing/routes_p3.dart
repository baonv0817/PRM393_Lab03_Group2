import 'package:breakbite/routing/route_helpers.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:go_router/go_router.dart';

// P3: account S15–S17, S26 sign-in, S27 kiosk picker, and the Firebase demo area.

/// Tab root: S15 Profile.
final GoRoute profileRoute = placeholderRoute(AppRoutes.profile, 'S15', 'Cá nhân', 'P3', showBack: false);

/// Full-screen routes of P3.
final List<GoRoute> p3Routes = [
  placeholderRoute(AppRoutes.signIn, 'S26', 'Đăng nhập', 'P3'),
  placeholderRoute(AppRoutes.profileInfo, 'S16', 'Hồ sơ sinh viên', 'P3'),
  placeholderRoute(AppRoutes.profilePayment, 'S17', 'Phương thức thanh toán', 'P3'),
  placeholderRoute(AppRoutes.firebaseDemo, 'DEMO', 'Khu demo Firebase', 'P3'),
  placeholderRoute(AppRoutes.kiosks, 'S27', 'Chọn kiosk', 'P3'),
];
