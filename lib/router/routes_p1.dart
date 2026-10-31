import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/app_services.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/home_view_model.dart';
import 'route_helpers.dart';

// P1: ordering flow S01–S08, S25, S29 (S21 is a state of Home, S22 is the alternatives screen).
// See docs/design-traceability.md.

/// Tab root: S02 Home. The pattern for wiring a real screen: create the ViewModel in the route,
/// the screen only reads it.
final GoRoute homeRoute = GoRoute(
  path: '/home',
  builder: (context, state) {
    final services = context.read<AppServices>();
    final uid = context.read<AuthViewModel>().user?.uid ?? '';
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(
        menu: services.menu,
        cart: services.cart,
        orders: services.orders,
        remoteConfig: services.remoteConfig,
        analytics: services.analytics,
        uid: uid,
      ),
      child: const HomeScreen(),
    );
  },
);

/// Tab root: S03 Menu.
final GoRoute menuRoute = placeholderRoute('/menu', 'S03', 'Thực đơn', 'P1', showBack: false);

/// Tab root: S08 Orders.
final GoRoute ordersRoute = placeholderRoute('/orders', 'S08', 'Đơn hàng', 'P1', showBack: false);

/// Full-screen routes of P1.
final List<GoRoute> p1Routes = [
  GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
  placeholderRoute('/menu/:id', 'S04', 'Chi tiết món', 'P1'),
  placeholderRoute('/menu/:id/alternatives', 'S22', 'Món hết, gợi ý thay thế', 'P1'),
  placeholderRoute('/cart', 'S05', 'Giỏ hàng', 'P1'),
  placeholderRoute('/cart/pickup-time', 'S25', 'Hẹn giờ nhận', 'P1'),
  placeholderRoute('/cart/vouchers', 'S29', 'Chọn mã giảm giá', 'P1'),
  placeholderRoute('/checkout', 'S06', 'Thanh toán', 'P1'),
  placeholderRoute('/checkout/gateway', 'S06-GATEWAY', 'Cổng thanh toán', 'P1'),
  placeholderRoute('/orders/:id', 'S07', 'Theo dõi đơn', 'P1'),
];
