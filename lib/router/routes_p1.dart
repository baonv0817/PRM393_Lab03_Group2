import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/app_services.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/home_view_model.dart';
import 'route_helpers.dart';

// P1: luồng đặt món S01–S08 (xem docs/design-traceability.md).
/// Gốc của tab: S02 Trang chủ. Mẫu nối một màn thật: tạo ViewModel ở route, màn chỉ đọc nó.
final GoRoute homeRoute = GoRoute(
  path: '/home',
  builder: (context, state) {
    final services = context.read<AppServices>();
    final uid = context.read<AuthViewModel>().user?.uid ?? '';
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(
        menu: services.menu,
        cart: services.cart,
        remoteConfig: services.remoteConfig,
        analytics: services.analytics,
        uid: uid,
      ),
      child: const HomeScreen(),
    );
  },
);

/// Gốc của tab: S03 Thực đơn.
final GoRoute menuRoute = placeholderRoute('/menu', 'S03', 'Thực đơn', 'P1', showBack: false);

/// Gốc của tab: S08 Đơn hàng.
final GoRoute ordersRoute = placeholderRoute('/orders', 'S08', 'Đơn hàng', 'P1', showBack: false);

/// Route toàn màn hình của P1.
final List<GoRoute> p1Routes = [
  GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
  placeholderRoute('/menu/:id', 'S04', 'Chi tiết món', 'P1'),
  placeholderRoute('/cart', 'S05', 'Giỏ hàng', 'P1'),
  placeholderRoute('/checkout', 'S06', 'Thanh toán', 'P1'),
  placeholderRoute('/checkout/gateway', 'S06-GATEWAY', 'Cổng thanh toán', 'P1'),
  placeholderRoute('/orders/:id', 'S07', 'Theo dõi đơn', 'P1'),
];
