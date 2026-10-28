import 'package:go_router/go_router.dart';

import 'route_helpers.dart';

// P3: tài khoản S15–S18, S26 và khu demo Firebase.
/// Gốc của tab: S15 Cá nhân.
final GoRoute profileRoute = placeholderRoute('/profile', 'S15', 'Cá nhân', 'P3', showBack: false);

/// Route toàn màn hình của P3.
final List<GoRoute> p3Routes = [
  placeholderRoute('/sign-in', 'S26', 'Đăng nhập', 'P3'),
  placeholderRoute('/profile/info', 'S16', 'Hồ sơ sinh viên', 'P3'),
  placeholderRoute('/profile/payment', 'S17', 'Phương thức thanh toán', 'P3'),
  placeholderRoute('/profile/notifications', 'S18', 'Cài đặt thông báo', 'P3'),
  placeholderRoute('/profile/firebase-demo', 'DEMO', 'Khu demo Firebase', 'P3'),
];
