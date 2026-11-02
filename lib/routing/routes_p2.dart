import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/order_manage/view_models/edit_order_view_model.dart';
import 'package:breakbite/ui/order_manage/view_models/incident_view_model.dart';
import 'package:breakbite/ui/order_manage/view_models/order_cancelled_view_model.dart';
import 'package:breakbite/ui/order_manage/view_models/order_detail_view_model.dart';
import 'package:breakbite/ui/order_manage/view_models/order_history_view_model.dart';
import 'package:breakbite/ui/order_manage/view_models/pickup_view_model.dart';
import 'package:breakbite/ui/order_manage/view_models/review_view_model.dart';
import 'package:breakbite/ui/order_manage/widgets/edit_order_screen.dart';
import 'package:breakbite/ui/order_manage/widgets/incident_screen.dart';
import 'package:breakbite/ui/order_manage/widgets/order_cancelled_screen.dart';
import 'package:breakbite/ui/order_manage/widgets/order_detail_screen.dart';
import 'package:breakbite/ui/order_manage/widgets/order_history_screen.dart';
import 'package:breakbite/ui/order_manage/widgets/pickup_screen.dart';
import 'package:breakbite/ui/order_manage/widgets/review_screen.dart';
import 'package:breakbite/ui/seller_menu/view_models/menu_item_form_view_model.dart';
import 'package:breakbite/ui/seller_menu/view_models/seller_menu_view_model.dart';
import 'package:breakbite/ui/seller_menu/widgets/menu_item_form_screen.dart';
import 'package:breakbite/ui/seller_menu/widgets/seller_menu_screen.dart';
import 'package:breakbite/ui/seller_shop/view_models/shift_stats_view_model.dart';
import 'package:breakbite/ui/seller_shop/view_models/shop_view_model.dart';
import 'package:breakbite/ui/seller_shop/widgets/shift_stats_screen.dart';
import 'package:breakbite/ui/seller_shop/widgets/shop_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// P2: post-order screens S09–S12, S20, S23, S24, and the seller's menu management K08–K11, K14, K15.
// A specific route (for example /orders/history) must come before a parameterized one (/orders/:id).

/// Seller tab root: K08 Menu management.
final GoRoute sellerMenuRoute = GoRoute(
  path: AppRoutes.sellerMenu,
  builder: (context, state) => ChangeNotifierProvider(
    create: (_) => SellerMenuViewModel(
      menu: context.read<MenuRepository>(),
      crash: context.read<CrashService>(),
      kioskId: context.read<AuthViewModel>().user?.kioskId,
    ),
    child: const SellerMenuScreen(),
  ),
);

/// Seller tab root: K10 Shop.
final GoRoute sellerShopRoute = GoRoute(
  path: AppRoutes.sellerShop,
  builder: (context, state) => ChangeNotifierProvider(
    create: (_) => ShopViewModel(
      menu: context.read<MenuRepository>(),
      crash: context.read<CrashService>(),
      kioskId: context.read<AuthViewModel>().user?.kioskId,
    ),
    child: const ShopScreen(),
  ),
);

/// Full-screen routes of P2.
final List<GoRoute> p2Routes = [
  GoRoute(
    path: AppRoutes.ordersHistory,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => OrderHistoryViewModel(
        orders: context.read<OrderRepository>(),
        crash: context.read<CrashService>(),
        uid: context.read<AuthViewModel>().user?.uid ?? '',
      ),
      child: const OrderHistoryScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.orderEdit,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => EditOrderViewModel(
        orders: context.read<OrderRepository>(),
        menu: context.read<MenuRepository>(),
        crash: context.read<CrashService>(),
        orderId: state.pathParameters['id'] ?? '',
      ),
      child: const EditOrderScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.orderCancelled,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => OrderCancelledViewModel(
        orders: context.read<OrderRepository>(),
        cart: context.read<CartRepository>(),
        session: context.read<SessionRepository>(),
        analytics: context.read<AnalyticsService>(),
        crash: context.read<CrashService>(),
        uid: context.read<AuthViewModel>().user?.uid ?? '',
        orderId: state.pathParameters['id'] ?? '',
      ),
      child: const OrderCancelledScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.orderDetail,
    builder: (context, state) {
      final user = context.read<AuthViewModel>().user;
      return ChangeNotifierProvider(
        create: (_) => OrderDetailViewModel(
          orders: context.read<OrderRepository>(),
          cart: context.read<CartRepository>(),
          session: context.read<SessionRepository>(),
          storage: context.read<StorageService>(),
          reportFiles: context.read<ReportFileService>(),
          reports: context.read<ReportRepository>(),
          analytics: context.read<AnalyticsService>(),
          crash: context.read<CrashService>(),
          uid: user?.uid ?? '',
          customerName: user?.displayName ?? 'Khách',
          orderId: state.pathParameters['id'] ?? '',
        ),
        child: const OrderDetailScreen(),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.orderPickup,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => PickupViewModel(
        orders: context.read<OrderRepository>(),
        crash: context.read<CrashService>(),
        orderId: state.pathParameters['id'] ?? '',
      ),
      child: const PickupScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.orderReview,
    builder: (context, state) {
      final user = context.read<AuthViewModel>().user;
      return ChangeNotifierProvider(
        create: (_) => ReviewViewModel(
          orders: context.read<OrderRepository>(),
          reviews: context.read<ReviewRepository>(),
          crash: context.read<CrashService>(),
          uid: user?.uid ?? '',
          displayName: user?.displayName ?? '',
          orderId: state.pathParameters['id'] ?? '',
        ),
        child: const ReviewScreen(),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.orderIncident,
    builder: (context, state) {
      final user = context.read<AuthViewModel>().user;
      return ChangeNotifierProvider(
        create: (_) => IncidentViewModel(
          orders: context.read<OrderRepository>(),
          incidents: context.read<IncidentRepository>(),
          crash: context.read<CrashService>(),
          uid: user?.uid ?? '',
          customerName: user?.displayName ?? '',
          orderId: state.pathParameters['id'] ?? '',
        ),
        child: const IncidentScreen(),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.sellerStats,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => ShiftStatsViewModel(
        orders: context.read<OrderRepository>(),
        menu: context.read<MenuRepository>(),
        crash: context.read<CrashService>(),
        kioskId: context.read<AuthViewModel>().user?.kioskId,
      ),
      child: const ShiftStatsScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.sellerMenuNew,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => MenuItemFormViewModel(
        menu: context.read<MenuRepository>(),
        crash: context.read<CrashService>(),
        kioskId: context.read<AuthViewModel>().user?.kioskId,
      ),
      child: const MenuItemFormScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.sellerMenuEdit,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => MenuItemFormViewModel(
        menu: context.read<MenuRepository>(),
        crash: context.read<CrashService>(),
        kioskId: context.read<AuthViewModel>().user?.kioskId,
        itemId: state.pathParameters['id'] ?? '',
      ),
      child: const MenuItemFormScreen(),
    ),
  ),
];
