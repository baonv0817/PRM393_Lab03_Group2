import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/cart/view_models/cart_view_model.dart';
import 'package:breakbite/ui/cart/view_models/pickup_time_view_model.dart';
import 'package:breakbite/ui/cart/view_models/voucher_picker_view_model.dart';
import 'package:breakbite/ui/cart/widgets/cart_screen.dart';
import 'package:breakbite/ui/cart/widgets/pickup_time_screen.dart';
import 'package:breakbite/ui/cart/widgets/voucher_picker_screen.dart';
import 'package:breakbite/ui/checkout/view_models/checkout_view_model.dart';
import 'package:breakbite/ui/checkout/widgets/checkout_screen.dart';
import 'package:breakbite/ui/checkout/widgets/gateway_screen.dart';
import 'package:breakbite/ui/home/view_models/home_view_model.dart';
import 'package:breakbite/ui/home/widgets/home_screen.dart';
import 'package:breakbite/ui/menu/view_models/alternatives_view_model.dart';
import 'package:breakbite/ui/menu/view_models/item_detail_view_model.dart';
import 'package:breakbite/ui/menu/view_models/menu_view_model.dart';
import 'package:breakbite/ui/menu/widgets/alternatives_screen.dart';
import 'package:breakbite/ui/menu/widgets/item_detail_screen.dart';
import 'package:breakbite/ui/menu/widgets/menu_screen.dart';
import 'package:breakbite/ui/onboarding/widgets/onboarding_screen.dart';
import 'package:breakbite/ui/orders/view_models/order_tracking_view_model.dart';
import 'package:breakbite/ui/orders/view_models/orders_view_model.dart';
import 'package:breakbite/ui/orders/widgets/order_tracking_screen.dart';
import 'package:breakbite/ui/orders/widgets/orders_screen.dart';
import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
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
        notifications: context.read<NotificationRepository>(),
      ),
      child: const HomeScreen(),
    );
  },
);

final GoRoute menuRoute = GoRoute(
  path: AppRoutes.menu,
  builder: (context, state) => ChangeNotifierProvider(
    create: (_) => MenuViewModel(
      menu: context.read<MenuRepository>(),
      cart: context.read<CartRepository>(),
      session: context.read<SessionRepository>(),
      analytics: context.read<AnalyticsService>(),
      crash: context.read<CrashService>(),
      uid: context.read<AuthViewModel>().user?.uid ?? '',
    ),
    child: const MenuScreen(),
  ),
);

final GoRoute ordersRoute = GoRoute(
  path: AppRoutes.orders,
  builder: (context, state) => ChangeNotifierProvider(
    create: (_) => OrdersViewModel(
      orders: context.read<OrderRepository>(),
      cart: context.read<CartRepository>(),
      session: context.read<SessionRepository>(),
      analytics: context.read<AnalyticsService>(),
      crash: context.read<CrashService>(),
      uid: context.read<AuthViewModel>().user?.uid ?? '',
    ),
    child: const OrdersScreen(),
  ),
);

final List<GoRoute> p1Routes = [
  GoRoute(path: AppRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
  GoRoute(
    path: AppRoutes.menuItem,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => ItemDetailViewModel(
        menu: context.read<MenuRepository>(),
        cart: context.read<CartRepository>(),
        analytics: context.read<AnalyticsService>(),
        crash: context.read<CrashService>(),
        uid: context.read<AuthViewModel>().user?.uid ?? '',
        itemId: state.pathParameters['id'] ?? '',
        favorites: context.read<FavoriteRepository>(),
      ),
      child: const ItemDetailScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.menuAlternatives,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => AlternativesViewModel(
        menu: context.read<MenuRepository>(),
        cart: context.read<CartRepository>(),
        analytics: context.read<AnalyticsService>(),
        crash: context.read<CrashService>(),
        uid: context.read<AuthViewModel>().user?.uid ?? '',
        itemId: state.pathParameters['id'] ?? '',
      ),
      child: const AlternativesScreen(),
    ),
  ),
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
  GoRoute(
    path: AppRoutes.cartPickupTime,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => PickupTimeViewModel(
        slots: context.read<SlotRepository>(),
        cart: context.read<CartRepository>(),
        menu: context.read<MenuRepository>(),
        remoteConfig: context.read<RemoteConfigService>(),
        crash: context.read<CrashService>(),
        uid: context.read<AuthViewModel>().user?.uid ?? '',
      ),
      child: const PickupTimeScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.cartVouchers,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => VoucherPickerViewModel(
        vouchers: context.read<VoucherRepository>(),
        menu: context.read<MenuRepository>(),
        cart: context.read<CartRepository>(),
        crash: context.read<CrashService>(),
        uid: context.read<AuthViewModel>().user?.uid ?? '',
      ),
      child: const VoucherPickerScreen(),
    ),
  ),
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
