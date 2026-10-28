import 'package:go_router/go_router.dart';

import 'route_helpers.dart';

// P4: app người bán K01–K15.
/// Gốc của tab: K02 Danh sách đơn.
final GoRoute sellerOrdersRoute = placeholderRoute('/seller/orders', 'K02', 'Danh sách đơn', 'P4', showBack: false);

/// Gốc của tab: K05 Quét mã nhận món.
final GoRoute sellerScanRoute = placeholderRoute('/seller/scan', 'K05', 'Quét mã nhận món', 'P4', showBack: false);

/// Gốc của tab: K08 Quản lý món.
final GoRoute sellerMenuRoute = placeholderRoute('/seller/menu', 'K08', 'Quản lý món', 'P4', showBack: false);

/// Gốc của tab: K10 Quán.
final GoRoute sellerShopRoute = placeholderRoute('/seller/shop', 'K10', 'Quán', 'P4', showBack: false);

/// Route toàn màn hình của P4.
final List<GoRoute> p4Routes = [
  placeholderRoute('/seller/sign-in', 'K01', 'Đăng nhập nhân viên', 'P4'),
  placeholderRoute('/seller/orders/:id', 'K03', 'Chi tiết đơn', 'P4'),
  placeholderRoute('/seller/orders/:id/preparing', 'K04', 'Đang chuẩn bị', 'P4'),
  placeholderRoute('/seller/orders/:id/deliver', 'K06', 'Xác nhận giao món', 'P4'),
  placeholderRoute('/seller/stats', 'K11', 'Thống kê ca', 'P4'),
  placeholderRoute('/seller/incidents', 'K13', 'Sự cố từ khách', 'P4'),
  placeholderRoute('/seller/menu/new', 'K14', 'Thêm món mới', 'P4'),
  placeholderRoute('/seller/menu/:id/edit', 'K15', 'Sửa món', 'P4'),
];
