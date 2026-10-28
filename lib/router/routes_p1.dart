import 'package:go_router/go_router.dart';

import 'route_helpers.dart';

// P1: luồng đặt món S01–S08 (xem docs/design-traceability.md).
/// Gốc của tab: S02 Trang chủ.
final GoRoute homeRoute = placeholderRoute('/home', 'S02', 'Trang chủ', 'P1', showBack: false);

/// Gốc của tab: S03 Thực đơn.
final GoRoute menuRoute = placeholderRoute('/menu', 'S03', 'Thực đơn', 'P1', showBack: false);

/// Gốc của tab: S08 Đơn hàng.
final GoRoute ordersRoute = placeholderRoute('/orders', 'S08', 'Đơn hàng', 'P1', showBack: false);

/// Route toàn màn hình của P1.
final List<GoRoute> p1Routes = [
  placeholderRoute('/onboarding', 'S01', 'Onboarding', 'P1'),
  placeholderRoute('/menu/:id', 'S04', 'Chi tiết món', 'P1'),
  placeholderRoute('/cart', 'S05', 'Giỏ hàng', 'P1'),
  placeholderRoute('/checkout', 'S06', 'Thanh toán', 'P1'),
  placeholderRoute('/checkout/gateway', 'S06-GATEWAY', 'Cổng thanh toán', 'P1'),
  placeholderRoute('/orders/:id', 'S07', 'Theo dõi đơn', 'P1'),
];
