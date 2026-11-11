import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/routing/route_helpers.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_incidents_view_model.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_order_view_model.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_orders_view_model.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_scan_view_model.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_deliver_screen.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_incidents_screen.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_order_screen.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_orders_screen.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_preparing_screen.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_scan_screen.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_sign_in_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// P4: the seller's order handling K01–K06, K12 (reject dialog, no route), K13.

Widget _order(BuildContext context, GoRouterState state, Widget screen) => forKiosk(
  (context, kioskId) => ChangeNotifierProvider(
    key: ValueKey(kioskId),
    create: (_) => SellerOrderViewModel(
      orders: context.read<OrderRepository>(),
      menu: context.read<MenuRepository>(),
      crash: context.read<CrashService>(),
      analytics: context.read<AnalyticsService>(),
      orderId: state.pathParameters['id'] ?? '',
      kioskId: kioskId,
    ),
    child: screen,
  ),
);

/// Seller tab root: K02 Order list.
final GoRoute sellerOrdersRoute = GoRoute(
  path: AppRoutes.sellerOrders,
  builder: (context, state) => forKiosk(
    (context, kioskId) => ChangeNotifierProvider(
      key: ValueKey(kioskId),
      create: (_) => SellerOrdersViewModel(
        orders: context.read<OrderRepository>(),
        menu: context.read<MenuRepository>(),
        incidents: context.read<IncidentRepository>(),
        crash: context.read<CrashService>(),
        analytics: context.read<AnalyticsService>(),
        alerts: context.read<OrderAlertService>(),
        kioskId: kioskId,
      ),
      child: const SellerOrdersScreen(),
    ),
  ),
);

/// Seller tab root: K05 Scan the pickup code.
final GoRoute sellerScanRoute = GoRoute(
  path: AppRoutes.sellerScan,
  builder: (context, state) => forKiosk(
    (context, kioskId) => ChangeNotifierProvider(
      key: ValueKey(kioskId),
      create: (_) => SellerScanViewModel(
        orders: context.read<OrderRepository>(),
        crash: context.read<CrashService>(),
        kioskId: kioskId,
      ),
      child: const SellerScanScreen(),
    ),
  ),
);

/// Full-screen routes of P4.
final List<GoRoute> p4Routes = [
  GoRoute(path: AppRoutes.sellerSignIn, builder: (context, state) => const SellerSignInScreen()),
  GoRoute(path: AppRoutes.sellerOrder, builder: (c, s) => _order(c, s, const SellerOrderScreen())),
  GoRoute(path: AppRoutes.sellerOrderPreparing, builder: (c, s) => _order(c, s, const SellerPreparingScreen())),
  GoRoute(path: AppRoutes.sellerOrderDeliver, builder: (c, s) => _order(c, s, const SellerDeliverScreen())),
  GoRoute(
    path: AppRoutes.sellerIncidents,
    builder: (context, state) => forKiosk(
      (context, kioskId) => ChangeNotifierProvider(
        key: ValueKey(kioskId),
        create: (_) => SellerIncidentsViewModel(
          incidents: context.read<IncidentRepository>(),
          orders: context.read<OrderRepository>(),
          crash: context.read<CrashService>(),
          kioskId: kioskId,
          staffUid: context.read<AuthViewModel>().user?.uid ?? '',
        ),
        child: const SellerIncidentsScreen(),
      ),
    ),
  ),
];
