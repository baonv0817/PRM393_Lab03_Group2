/// Every path in the app. Route definitions and navigation (`context.push`, `context.go`) all use the
/// constants here, never hand-written strings. Parameterized paths also get a builder, e.g. [menuItemOf].
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';

  static const home = '/home';
  static const search = '/search';
  static const kiosks = '/kiosks';
  static const notifications = '/notifications';
  static const favorites = '/favorites';

  static const menu = '/menu';
  static const menuItem = '/menu/:id';
  static String menuItemOf(String id) => '/menu/$id';
  static const menuAlternatives = '/menu/:id/alternatives';
  static String menuAlternativesOf(String id) => '/menu/$id/alternatives';

  static const cart = '/cart';
  static const cartPickupTime = '/cart/pickup-time';
  static const cartVouchers = '/cart/vouchers';
  static const checkout = '/checkout';
  static const checkoutGateway = '/checkout/gateway';

  static const orders = '/orders';
  static const ordersHistory = '/orders/history';
  static const order = '/orders/:id';
  static String orderOf(String id) => '/orders/$id';
  static const orderEdit = '/orders/:id/edit';
  static String orderEditOf(String id) => '/orders/$id/edit';
  static const orderCancelled = '/orders/:id/cancelled';
  static String orderCancelledOf(String id) => '/orders/$id/cancelled';
  static const orderDetail = '/orders/:id/detail';
  static String orderDetailOf(String id) => '/orders/$id/detail';
  static const orderPickup = '/orders/:id/pickup';
  static String orderPickupOf(String id) => '/orders/$id/pickup';
  static const orderReview = '/orders/:id/review';
  static String orderReviewOf(String id) => '/orders/$id/review';
  static const orderIncident = '/orders/:id/incident';
  static String orderIncidentOf(String id) => '/orders/$id/incident';

  static const profile = '/profile';
  static const profileInfo = '/profile/info';
  static const profilePayment = '/profile/payment';
  static const profileNotifications = '/profile/notifications';
  static const firebaseDemo = '/profile/firebase-demo';

  static const sellerPrefix = '/seller';
  static const sellerSignIn = '/seller/sign-in';
  static const sellerOrders = '/seller/orders';
  static const sellerOrder = '/seller/orders/:id';
  static String sellerOrderOf(String id) => '/seller/orders/$id';
  static const sellerOrderPreparing = '/seller/orders/:id/preparing';
  static String sellerOrderPreparingOf(String id) => '/seller/orders/$id/preparing';
  static const sellerOrderDeliver = '/seller/orders/:id/deliver';
  static String sellerOrderDeliverOf(String id) => '/seller/orders/$id/deliver';
  static const sellerScan = '/seller/scan';
  static const sellerIncidents = '/seller/incidents';
  static const sellerMenu = '/seller/menu';
  static const sellerMenuNew = '/seller/menu/new';
  static const sellerMenuEdit = '/seller/menu/:id/edit';
  static String sellerMenuEditOf(String id) => '/seller/menu/$id/edit';
  static const sellerShop = '/seller/shop';
  static const sellerStats = '/seller/stats';
}
