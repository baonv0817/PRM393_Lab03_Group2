import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/favorites/view_models/favorites_view_model.dart';
import 'package:breakbite/ui/favorites/widgets/favorites_screen.dart';
import 'package:breakbite/ui/notifications/view_models/notification_center_view_model.dart';
import 'package:breakbite/ui/notifications/view_models/notification_settings_view_model.dart';
import 'package:breakbite/ui/notifications/widgets/notification_center_screen.dart';
import 'package:breakbite/ui/notifications/widgets/notification_settings_screen.dart';
import 'package:breakbite/ui/search/view_models/search_view_model.dart';
import 'package:breakbite/ui/search/widgets/search_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// P5: favorites S13, notification settings S18, notifications S19, search S28
// (S14 is a bottom sheet of Home and S30 is an app-wide state, so neither has a route).

String _uid(BuildContext context) => context.read<AuthViewModel>().user?.uid ?? '';

/// Full-screen routes of P5.
final List<GoRoute> p5Routes = [
  GoRoute(
    path: AppRoutes.favorites,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => FavoritesViewModel(
        favorites: context.read<FavoriteRepository>(),
        menu: context.read<MenuRepository>(),
        cart: context.read<CartRepository>(),
        orders: context.read<OrderRepository>(),
        session: context.read<SessionRepository>(),
        analytics: context.read<AnalyticsService>(),
        crash: context.read<CrashService>(),
        uid: _uid(context),
      ),
      child: const FavoritesScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.notifications,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => NotificationCenterViewModel(
        notifications: context.read<NotificationRepository>(),
        crash: context.read<CrashService>(),
        uid: _uid(context),
      ),
      child: const NotificationCenterScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.profileNotifications,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => NotificationSettingsViewModel(
        notifications: context.read<NotificationRepository>(),
        crash: context.read<CrashService>(),
        uid: _uid(context),
      ),
      child: const NotificationSettingsScreen(),
    ),
  ),
  GoRoute(
    path: AppRoutes.search,
    builder: (context, state) => ChangeNotifierProvider(
      create: (_) => SearchViewModel(
        menu: context.read<MenuRepository>(),
        cart: context.read<CartRepository>(),
        session: context.read<SessionRepository>(),
        analytics: context.read<AnalyticsService>(),
        crash: context.read<CrashService>(),
        uid: _uid(context),
      ),
      child: const SearchScreen(),
    ),
  ),
];
