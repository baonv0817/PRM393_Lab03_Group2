abstract final class AnalyticsEvents {
  static const login = 'login';
  static const logout = 'logout';
  static const search = 'search';
  static const addToCart = 'add_to_cart';
  static const reorder = 'reorder';
  static const exportReport = 'export_report';
  static const beginCheckout = 'begin_checkout';
  static const purchase = 'purchase';
  static const paymentFailed = 'payment_failed';
  static const viewMenuItem = 'view_menu_item';
  static const orderAccepted = 'order_accepted';
  static const orderDelivered = 'order_delivered';

  /// The Gemini feature of K14 (docs/ai-feature.md, docs/analytics-plan.md).
  static const aiRequest = 'ai_request';
  static const aiResultAccepted = 'ai_result_accepted';
  static const aiError = 'ai_error';
}
