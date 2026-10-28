import 'package:go_router/go_router.dart';

import 'route_helpers.dart';

// P2: S09–S14, S19–S25, S27–S30. Route cụ thể (ví dụ /orders/history) phải đứng trước route có tham số (/orders/:id).
/// Route toàn màn hình của P2.
final List<GoRoute> p2Routes = [
  placeholderRoute('/orders/history', 'S11', 'Lịch sử đơn', 'P2'),
  placeholderRoute('/orders/:id/edit', 'S09', 'Sửa đơn', 'P2'),
  placeholderRoute('/orders/:id/cancelled', 'S10', 'Đơn đã huỷ', 'P2'),
  placeholderRoute('/orders/:id/detail', 'S12', 'Chi tiết đơn', 'P2'),
  placeholderRoute('/orders/:id/pickup', 'S20', 'Nhận món bằng mã QR', 'P2'),
  placeholderRoute('/orders/:id/review', 'S23', 'Đánh giá món', 'P2'),
  placeholderRoute('/orders/:id/incident', 'S24', 'Báo sự cố', 'P2'),
  placeholderRoute('/favorites', 'S13', 'Món yêu thích', 'P2'),
  placeholderRoute('/notifications', 'S19', 'Thông báo', 'P2'),
  placeholderRoute('/menu/:id/alternatives', 'S22', 'Món hết, gợi ý thay thế', 'P2'),
  placeholderRoute('/cart/pickup-time', 'S25', 'Hẹn giờ nhận', 'P2'),
  placeholderRoute('/cart/vouchers', 'S29', 'Chọn mã giảm giá', 'P2'),
  placeholderRoute('/kiosks', 'S27', 'Chọn kiosk', 'P2'),
  placeholderRoute('/search', 'S28', 'Tìm kiếm', 'P2'),
];
