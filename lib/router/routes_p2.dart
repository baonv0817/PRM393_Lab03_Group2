import 'package:go_router/go_router.dart';

import 'route_helpers.dart';

// P2: post-order screens S09–S12, S20, S23, S24, and the seller's menu management K08–K11, K14, K15.
// A specific route (for example /orders/history) must come before a parameterized one (/orders/:id).

/// Seller tab root: K08 Menu management.
final GoRoute sellerMenuRoute = placeholderRoute('/seller/menu', 'K08', 'Quản lý món', 'P2', showBack: false);

/// Seller tab root: K10 Shop.
final GoRoute sellerShopRoute = placeholderRoute('/seller/shop', 'K10', 'Quán', 'P2', showBack: false);

/// Full-screen routes of P2.
final List<GoRoute> p2Routes = [
  placeholderRoute('/orders/history', 'S11', 'Lịch sử đơn', 'P2'),
  placeholderRoute('/orders/:id/edit', 'S09', 'Sửa đơn', 'P2'),
  placeholderRoute('/orders/:id/cancelled', 'S10', 'Đơn đã huỷ', 'P2'),
  placeholderRoute('/orders/:id/detail', 'S12', 'Chi tiết đơn', 'P2'),
  placeholderRoute('/orders/:id/pickup', 'S20', 'Nhận món bằng mã QR', 'P2'),
  placeholderRoute('/orders/:id/review', 'S23', 'Đánh giá món', 'P2'),
  placeholderRoute('/orders/:id/incident', 'S24', 'Báo sự cố', 'P2'),
  placeholderRoute('/seller/stats', 'K11', 'Thống kê ca', 'P2'),
  placeholderRoute('/seller/menu/new', 'K14', 'Thêm món mới', 'P2'),
  placeholderRoute('/seller/menu/:id/edit', 'K15', 'Sửa món', 'P2'),
];
