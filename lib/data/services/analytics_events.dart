/// Tên sự kiện Analytics (khớp `docs/analytics-plan.md`). Dùng hằng ở đây, không viết chuỗi tay.
abstract final class AnalyticsEvents {
  static const login = 'login';
  static const logout = 'logout';
  static const addToCart = 'add_to_cart';
  static const reorder = 'reorder';
}
