import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/routing/route_helpers.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/home/view_models/home_view_model.dart';
import 'package:breakbite/ui/home/widgets/home_screen.dart';
import 'package:breakbite/ui/onboarding/widgets/onboarding_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// P1: ordering flow S01–S08, S25, S29 (S21 is a state of Home, S22 is the alternatives screen).
// See docs/design-traceability.md.

/// Tab root: S02 Home. The pattern for wiring a real screen: create the ViewModel in the route,
/// the screen only reads it.
final GoRoute homeRoute = GoRoute(
  path: AppRoutes.home,
  builder: (context, state) {
    final uid = context.read<AuthViewModel>().user?.uid ?? '';
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(
        menu: context.read<MenuRepository>(),
        cart: context.read<CartRepository>(),
        orders: context.read<OrderRepository>(),
        session: context.read<SessionRepository>(),
        remoteConfig: context.read<RemoteConfigService>(),
        analytics: context.read<AnalyticsService>(),
        crash: context.read<CrashService>(),
        uid: uid,
      ),
      child: const HomeScreen(),
    );
  },
);

/// Tab root: S03 Menu.
final GoRoute menuRoute = placeholderRoute(AppRoutes.menu, 'S03', 'Thực đơn', 'P1', showBack: false);

/// Tab root: S08 Orders.
final GoRoute ordersRoute = placeholderRoute(AppRoutes.orders, 'S08', 'Đơn hàng', 'P1', showBack: false);

/// Full-screen routes of P1.
final List<GoRoute> p1Routes = [
  GoRoute(path: AppRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
  placeholderRoute(AppRoutes.menuItem, 'S04', 'Chi tiết món', 'P1'),
  placeholderRoute(AppRoutes.menuAlternatives, 'S22', 'Món hết, gợi ý thay thế', 'P1'),
  placeholderRoute(AppRoutes.cart, 'S05', 'Giỏ hàng', 'P1'),
  placeholderRoute(AppRoutes.cartPickupTime, 'S25', 'Hẹn giờ nhận', 'P1'),
  placeholderRoute(AppRoutes.cartVouchers, 'S29', 'Chọn mã giảm giá', 'P1'),
  placeholderRoute(AppRoutes.checkout, 'S06', 'Thanh toán', 'P1'),
  placeholderRoute(AppRoutes.checkoutGateway, 'S06-GATEWAY', 'Cổng thanh toán', 'P1'),
  placeholderRoute(AppRoutes.order, 'S07', 'Theo dõi đơn', 'P1'),
];
