import 'package:go_router/go_router.dart';

import 'route_helpers.dart';

// P3: account S15–S17, S26 sign-in, S27 kiosk picker, and the Firebase demo area.

/// Tab root: S15 Profile.
final GoRoute profileRoute = placeholderRoute('/profile', 'S15', 'Cá nhân', 'P3', showBack: false);

/// Full-screen routes of P3.
final List<GoRoute> p3Routes = [
  placeholderRoute('/sign-in', 'S26', 'Đăng nhập', 'P3'),
  placeholderRoute('/profile/info', 'S16', 'Hồ sơ sinh viên', 'P3'),
  placeholderRoute('/profile/payment', 'S17', 'Phương thức thanh toán', 'P3'),
  placeholderRoute('/profile/firebase-demo', 'DEMO', 'Khu demo Firebase', 'P3'),
  placeholderRoute('/kiosks', 'S27', 'Chọn kiosk', 'P3'),
];
