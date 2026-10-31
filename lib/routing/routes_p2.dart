import 'package:go_router/go_router.dart';

import 'route_helpers.dart';
import 'routes.dart';

// P2: post-order screens S09–S12, S20, S23, S24, and the seller's menu management K08–K11, K14, K15.
// A specific route (for example /orders/history) must come before a parameterized one (/orders/:id).

/// Seller tab root: K08 Menu management.
final GoRoute sellerMenuRoute = placeholderRoute(AppRoutes.sellerMenu, 'K08', 'Quản lý món', 'P2', showBack: false);

/// Seller tab root: K10 Shop.
final GoRoute sellerShopRoute = placeholderRoute(AppRoutes.sellerShop, 'K10', 'Quán', 'P2', showBack: false);

/// Full-screen routes of P2.
final List<GoRoute> p2Routes = [
  placeholderRoute(AppRoutes.ordersHistory, 'S11', 'Lịch sử đơn', 'P2'),
  placeholderRoute(AppRoutes.orderEdit, 'S09', 'Sửa đơn', 'P2'),
  placeholderRoute(AppRoutes.orderCancelled, 'S10', 'Đơn đã huỷ', 'P2'),
  placeholderRoute(AppRoutes.orderDetail, 'S12', 'Chi tiết đơn', 'P2'),
  placeholderRoute(AppRoutes.orderPickup, 'S20', 'Nhận món bằng mã QR', 'P2'),
  placeholderRoute(AppRoutes.orderReview, 'S23', 'Đánh giá món', 'P2'),
  placeholderRoute(AppRoutes.orderIncident, 'S24', 'Báo sự cố', 'P2'),
  placeholderRoute(AppRoutes.sellerStats, 'K11', 'Thống kê ca', 'P2'),
  placeholderRoute(AppRoutes.sellerMenuNew, 'K14', 'Thêm món mới', 'P2'),
  placeholderRoute(AppRoutes.sellerMenuEdit, 'K15', 'Sửa món', 'P2'),
];
