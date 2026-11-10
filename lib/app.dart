import 'dart:async';

import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/data/order_status_notifier.dart';
import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/router.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/offline/view_models/connectivity_view_model.dart';
import 'package:breakbite/ui/offline/widgets/offline_gate.dart';
import 'package:breakbite/ui/seller_orders/widgets/qr_camera_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class BreakBiteApp extends StatelessWidget {
  const BreakBiteApp({super.key, required this.dependencies, this.qrCamera});

  final AppDependencies dependencies;

  /// The camera K05 uses to read pickup QR codes; `null` (tests, the fake-data app) leaves typed entry only.
  final QrCameraBuilder? qrCamera;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ...dependencies.providers,
        Provider<QrCameraBuilder?>.value(value: qrCamera),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthService>(),
            context.read<AnalyticsService>(),
            context.read<CrashService>(),
            context.read<SessionRepository>(),
            context.read<MessagingService>(),
          ),
        ),
        ChangeNotifierProvider<ConnectivityViewModel>(
          create: (context) => ConnectivityViewModel(
            connectivity: context.read<ConnectivityService>(),
            crash: context.read<CrashService>(),
          ),
        ),
      ],
      child: const _RouterHost(),
    );
  }
}

class _RouterHost extends StatefulWidget {
  const _RouterHost();

  @override
  State<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends State<_RouterHost> {
  late final AuthViewModel _auth = context.read<AuthViewModel>();
  late final GoRouter _router = createRouter(_auth);
  late final OrderStatusNotifier _notifier = OrderStatusNotifier(
    orders: context.read<OrderRepository>(),
    notifications: context.read<NotificationRepository>(),
    crash: context.read<CrashService>(),
  );
  late final MessagingService _messaging = context.read<MessagingService>();
  StreamSubscription<AppNotification>? _openedSub;
  String? _notifiedUid;

  @override
  void initState() {
    super.initState();
    // Read the repositories now: a lazy field would read them for the first time in dispose, too late.
    _notifier;
    _auth.addListener(_syncNotifier);
    _syncNotifier();
    // A push notification tapped in the system tray (app in the background or closed) opens its screen.
    _openedSub = _messaging.openedMessages().listen(_openFromNotification);
  }

  /// Where a tapped notification leads: the order it is about, or the notification list. Nothing happens
  /// while nobody is signed in (the sign-in screen comes first), and the staff app has no S19.
  void _openFromNotification(AppNotification notification) {
    final user = _auth.user;
    if (user == null || user.isStaff) return;
    _router.go(destinationOfNotification(notification));
  }

  /// The customer's order changes become notifications (S19) while a customer is signed in.
  void _syncNotifier() {
    final user = _auth.user;
    final uid = user != null && !user.isStaff ? user.uid : null;
    if (uid == _notifiedUid) return;
    _notifiedUid = uid;
    if (uid == null) {
      _notifier.stop();
    } else {
      _notifier.start(uid);
    }
  }

  @override
  void dispose() {
    unawaited(_openedSub?.cancel());
    _auth.removeListener(_syncNotifier);
    _notifier.stop();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BreakBite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
      // S30 covers the whole app while the phone is offline.
      builder: (context, child) => ListenableBuilder(
        listenable: _auth,
        builder: (context, _) => OfflineGate(
          canViewCart: _auth.user != null && !_auth.user!.isStaff,
          onViewCart: () => _router.go(AppRoutes.cart),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The screen a notification opens: the pickup code of an order that is ready, the tracking screen of any
/// other order, the notification list for a message that is not about an order.
String destinationOfNotification(AppNotification notification) {
  final orderId = notification.orderId;
  if (orderId == null || orderId.isEmpty) return AppRoutes.notifications;
  return notification.id == AppNotification.idForOrder(orderId, OrderStatus.ready)
      ? AppRoutes.orderPickupOf(orderId)
      : AppRoutes.orderOf(orderId);
}
