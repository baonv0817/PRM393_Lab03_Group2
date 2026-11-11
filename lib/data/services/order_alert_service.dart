/// Tells the staff of a kiosk that new orders came in (K02): the phone rings, vibrates and shows a notification,
/// even with the screen off or another app in front. The app has no server to push this when it is closed
/// (data-model section 6), so it works while the seller app is running.
abstract interface class OrderAlertService {
  /// [count] orders are waiting to be accepted; [orderCode] is the one order's code when it is a single order.
  /// Never throws: an alert that cannot be shown is simply not shown.
  Future<void> newOrders({required int count, String? orderCode});
}
