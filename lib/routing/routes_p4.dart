import 'package:breakbite/routing/route_helpers.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:go_router/go_router.dart';

// P4: the seller's order handling K01–K06, K12 (reject dialog, no route), K13.

/// Seller tab root: K02 Order list.
final GoRoute sellerOrdersRoute = placeholderRoute(
  AppRoutes.sellerOrders,
  'K02',
  'Danh sách đơn',
  'P4',
  showBack: false,
);

/// Seller tab root: K05 Scan the pickup code.
final GoRoute sellerScanRoute = placeholderRoute(
  AppRoutes.sellerScan,
  'K05',
  'Quét mã nhận món',
  'P4',
  showBack: false,
);

/// Full-screen routes of P4.
final List<GoRoute> p4Routes = [
  placeholderRoute(AppRoutes.sellerSignIn, 'K01', 'Đăng nhập nhân viên', 'P4'),
  placeholderRoute(AppRoutes.sellerOrder, 'K03', 'Chi tiết đơn', 'P4'),
  placeholderRoute(AppRoutes.sellerOrderPreparing, 'K04', 'Đang chuẩn bị', 'P4'),
  placeholderRoute(AppRoutes.sellerOrderDeliver, 'K06', 'Xác nhận giao món', 'P4'),
  placeholderRoute(AppRoutes.sellerIncidents, 'K13', 'Sự cố từ khách', 'P4'),
];
