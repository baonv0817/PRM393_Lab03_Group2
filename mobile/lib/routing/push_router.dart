import 'dart:async';

import 'package:breakbite/routing/routes.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/models/models.dart';

/// T53: what happens to a push notification once it reaches the app.
///
/// - Tapped in the system tray (app in the background, or started from it): open the screen it is about,
///   the order (S07) when it names one, otherwise the notification center (S19). When the app was started by
///   the tap, the sign-in state is not known yet, so the screen opens as soon as a customer is signed in.
/// - Received while the app is open: [showBanner] shows it in the app with a way to open the same screen.
///
/// Staff accounts are left alone: the seller app has no customer screens to open.
class PushRouter {
  PushRouter({
    required this.messaging,
    required this.crash,
    required this.currentUser,
    required this.go,
    required this.showBanner,
  });

  final MessagingService messaging;
  final CrashService crash;

  /// The signed-in user right now, or `null`.
  final AppUser? Function() currentUser;

  /// Opens a route (`GoRouter.push`).
  final void Function(String route) go;

  /// Shows a notification received in the foreground; the banner calls `open` when tapped.
  final void Function(AppNotification notification, void Function() open) showBanner;

  StreamSubscription<AppNotification>? _openedSub;
  StreamSubscription<AppNotification>? _foregroundSub;
  String? _pending;

  /// The screen a notification is about.
  static String routeFor(AppNotification notification) {
    final orderId = notification.orderId;
    return orderId == null || orderId.isEmpty ? AppRoutes.notifications : AppRoutes.orderOf(orderId);
  }

  /// A route waiting for the sign-in state, for tests.
  String? get pending => _pending;

  void start() {
    _openedSub ??= messaging.openedMessages().listen(
      (n) => _open(routeFor(n)),
      onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'push.opened'),
    );
    _foregroundSub ??= messaging.foregroundMessages().listen((n) {
      if (_isCustomer) showBanner(n, () => go(routeFor(n)));
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'push.foreground'));
  }

  /// Call when the sign-in state changes: opens the screen of a notification that started the app.
  void onUserChanged() {
    final route = _pending;
    final user = currentUser();
    if (route == null || user == null) return;
    _pending = null;
    if (!user.isStaff) go(route);
  }

  bool get _isCustomer {
    final user = currentUser();
    return user != null && !user.isStaff;
  }

  void _open(String route) {
    final user = currentUser();
    if (user == null) {
      _pending = route;
    } else if (!user.isStaff) {
      go(route);
    }
  }

  void stop() {
    unawaited(_openedSub?.cancel());
    unawaited(_foregroundSub?.cancel());
    _openedSub = null;
    _foregroundSub = null;
  }
}
