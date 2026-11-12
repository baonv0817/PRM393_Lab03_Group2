import 'dart:async';

import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// S30: whether the app shows "Mất kết nối mạng". It shows while the phone is offline; "Xem giỏ hàng" hides it
/// until the connection changes again (the cart is kept on the phone, so it can be read offline), and "Thử lại"
/// asks the phone once more.
class ConnectivityViewModel extends ChangeNotifier with SafeChangeNotifier {
  ConnectivityViewModel({required this.connectivity, required this.crash}) {
    _sub = connectivity.watchOnline().listen(
      _onChanged,
      onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'connectivity.watch'),
    );
  }

  final ConnectivityService connectivity;
  final CrashService crash;

  late final StreamSubscription<bool> _sub;
  var _online = true;
  var _dismissed = false;
  var _checking = false;

  bool get online => _online;

  /// A check made with "Thử lại" is running.
  bool get checking => _checking;

  /// Whether the offline screen covers the app now.
  bool get showOffline => !_online && !_dismissed;

  void _onChanged(bool online) {
    if (online == _online) return;
    _online = online;
    // A new loss of connection shows the screen again, even after "Xem giỏ hàng".
    _dismissed = false;
    notifyListeners();
  }

  /// "Xem giỏ hàng": leaves the offline screen so the customer can read the cart.
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
  }

  /// "Thử lại": asks the phone again. The screen goes away by itself when the answer is online.
  Future<void> retry() async {
    if (_checking) return;
    _checking = true;
    notifyListeners();
    try {
      _onChanged(await connectivity.check());
    } catch (error, stack) {
      crash.recordNonFatal(error, stack, 'connectivity.check');
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
