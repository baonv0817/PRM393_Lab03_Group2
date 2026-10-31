import 'package:go_router/go_router.dart';

import 'route_helpers.dart';

// P4: the seller's order handling K01–K06, K12 (reject dialog, no route), K13.

/// Seller tab root: K02 Order list.
final GoRoute sellerOrdersRoute = placeholderRoute('/seller/orders', 'K02', 'Danh sách đơn', 'P4', showBack: false);

/// Seller tab root: K05 Scan the pickup code.
final GoRoute sellerScanRoute = placeholderRoute('/seller/scan', 'K05', 'Quét mã nhận món', 'P4', showBack: false);

/// Full-screen routes of P4.
final List<GoRoute> p4Routes = [
  placeholderRoute('/seller/sign-in', 'K01', 'Đăng nhập nhân viên', 'P4'),
  placeholderRoute('/seller/orders/:id', 'K03', 'Chi tiết đơn', 'P4'),
  placeholderRoute('/seller/orders/:id/preparing', 'K04', 'Đang chuẩn bị', 'P4'),
  placeholderRoute('/seller/orders/:id/deliver', 'K06', 'Xác nhận giao món', 'P4'),
  placeholderRoute('/seller/incidents', 'K13', 'Sự cố từ khách', 'P4'),
];
