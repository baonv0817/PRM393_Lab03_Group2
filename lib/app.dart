import 'dart:async';

import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/data/break_reminder_scheduler.dart';
import 'package:breakbite/data/order_status_notifier.dart';
import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/push_router.dart';
import 'package:breakbite/routing/router.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/offline/view_models/connectivity_view_model.dart';
import 'package:breakbite/ui/offline/widgets/offline_gate.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class BreakBiteApp extends StatelessWidget {
  const BreakBiteApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ...dependencies.providers,
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
  late final PushRouter _push = PushRouter(
    messaging: context.read<MessagingService>(),
    crash: context.read<CrashService>(),
    currentUser: () => _auth.user,
    go: (route) => unawaited(_router.push(route)),
    showBanner: _showBanner,
  );
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final BreakReminderScheduler _reminders = BreakReminderScheduler(
    notifications: context.read<NotificationRepository>(),
    session: context.read<SessionRepository>(),
    slots: context.read<SlotRepository>(),
    reminders: context.read<ReminderService>(),
    crash: context.read<CrashService>(),
  );
  String? _notifiedUid;

  @override
  void initState() {
    super.initState();
    // Read the repositories now: a lazy field would read them for the first time in dispose, too late.
    _notifier;
    _reminders;
    _auth.addListener(_syncNotifier);
    _syncNotifier();
    _auth.addListener(_push.onUserChanged);
    _push.start();
  }

  /// A push received while the app is open (T53): its title and text, and "Xem" opens the related screen.
  void _showBanner(AppNotification notification, void Function() open) {
    final text = notification.body.isEmpty ? notification.title : '${notification.title}: ${notification.body}';
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          persist: false,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'Xem', onPressed: open),
        ),
      );
  }

  /// The customer's order changes become notifications (S19) while a customer is signed in.
  void _syncNotifier() {
    final user = _auth.user;
    final uid = user != null && !user.isStaff ? user.uid : null;
    if (uid == _notifiedUid) return;
    _notifiedUid = uid;
    if (uid == null) {
      _notifier.stop();
      _reminders.stop();
    } else {
      _notifier.start(uid);
      _reminders.start(uid);
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_syncNotifier);
    _auth.removeListener(_push.onUserChanged);
    _push.stop();
    _notifier.stop();
    _reminders.stop();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BreakBite',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
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
