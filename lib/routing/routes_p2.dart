import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/routing/route_helpers.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/order_manage/view_models/order_cancelled_view_model.dart';
import 'package:breakbite/ui/order_manage/view_models/order_detail_view_model.dart';
import 'package:breakbite/ui/order_manage/view_models/order_history_view_model.dart';
import 'package:breakbite/ui/order_manage/widgets/order_cancelled_screen.dart';
import 'package:breakbite/ui/order_manage/widgets/order_detail_screen.dart';
import 'package:breakbite/ui/order_manage/widgets/order_history_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// P2: post-order screens S09–S12, S20, S23, S24, and the seller's menu management K08–K11, K14, K15.
// A specific route (for example /orders/history) must come before a parameterized one (/orders/:id).

/// Seller tab root: K08 Menu management.
final GoRoute sellerMenuRoute = placeholderRoute(AppRoutes.sellerMenu, 'K08', 'Quản lý món', 'P2', showBack: false);

/// Seller tab root: K10 Shop.
final GoRoute sellerShopRoute = placeholderRoute(AppRoutes.sellerShop, 'K10', 'Quán', 'P2', showBack: false);

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
  placeholderRoute(AppRoutes.orderEdit, 'S09', 'Sửa đơn', 'P2'),
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
  placeholderRoute(AppRoutes.orderPickup, 'S20', 'Nhận món bằng mã QR', 'P2'),
  placeholderRoute(AppRoutes.orderReview, 'S23', 'Đánh giá món', 'P2'),
  placeholderRoute(AppRoutes.orderIncident, 'S24', 'Báo sự cố', 'P2'),
  placeholderRoute(AppRoutes.sellerStats, 'K11', 'Thống kê ca', 'P2'),
  placeholderRoute(AppRoutes.sellerMenuNew, 'K14', 'Thêm món mới', 'P2'),
  placeholderRoute(AppRoutes.sellerMenuEdit, 'K15', 'Sửa món', 'P2'),
];
