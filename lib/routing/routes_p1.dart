import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/routing/route_helpers.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/cart/view_models/cart_view_model.dart';
import 'package:breakbite/ui/cart/widgets/cart_screen.dart';
import 'package:breakbite/ui/checkout/view_models/checkout_view_model.dart';
import 'package:breakbite/ui/checkout/widgets/checkout_screen.dart';
import 'package:breakbite/ui/checkout/widgets/gateway_screen.dart';
import 'package:breakbite/ui/home/view_models/home_view_model.dart';
import 'package:breakbite/ui/home/widgets/home_screen.dart';
import 'package:breakbite/ui/onboarding/widgets/onboarding_screen.dart';
import 'package:breakbite/ui/orders/view_models/order_tracking_view_model.dart';
import 'package:breakbite/ui/orders/widgets/order_tracking_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

final GoRoute menuRoute = placeholderRoute(AppRoutes.menu, 'S03', 'Thực đơn', 'P1', showBack: false);

final GoRoute ordersRoute = placeholderRoute(AppRoutes.orders, 'S08', 'Đơn hàng', 'P1', showBack: false);

final List<GoRoute> p1Routes = [
  GoRoute(path: AppRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
  placeholderRoute(AppRoutes.menuItem, 'S04', 'Chi tiết món', 'P1'),
  placeholderRoute(AppRoutes.menuAlternatives, 'S22', 'Món hết, gợi ý thay thế', 'P1'),
  GoRoute(
    path: AppRoutes.cart,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => CartViewModel(
        cart: context.read<CartRepository>(),
        menu: context.read<MenuRepository>(),
        crash: context.read<CrashService>(),
        uid: context.read<AuthViewModel>().user?.uid ?? '',
      ),
      child: const CartScreen(),
    ),
  ),
  placeholderRoute(AppRoutes.cartPickupTime, 'S25', 'Hẹn giờ nhận', 'P1'),
  placeholderRoute(AppRoutes.cartVouchers, 'S29', 'Chọn mã giảm giá', 'P1'),
  GoRoute(
    path: AppRoutes.checkout,
    builder: (context, state) {
      final user = context.read<AuthViewModel>().user;
      return ChangeNotifierProvider(
        create: (_) => CheckoutViewModel(
          cart: context.read<CartRepository>(),
          menu: context.read<MenuRepository>(),
          orders: context.read<OrderRepository>(),
          users: context.read<UserRepository>(),
          analytics: context.read<AnalyticsService>(),
          crash: context.read<CrashService>(),
          uid: user?.uid ?? '',
          customerName: user?.displayName ?? 'Khách',
        ),
        child: const CheckoutScreen(),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.checkoutGateway,
    redirect: (context, state) => state.extra is CheckoutViewModel ? null : AppRoutes.cart,
    builder: (context, state) => ChangeNotifierProvider<CheckoutViewModel>.value(
      value: state.extra! as CheckoutViewModel,
      child: const GatewayScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.order,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => OrderTrackingViewModel(
        orders: context.read<OrderRepository>(),
        menu: context.read<MenuRepository>(),
        crash: context.read<CrashService>(),
        orderId: state.pathParameters['id'] ?? '',
      ),
      child: const OrderTrackingScreen(),
    ),
  ),
];
