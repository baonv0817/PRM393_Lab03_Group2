import 'dart:async';

import 'package:breakbite_admin/config/browser_connectivity.dart';
import 'package:breakbite_admin/config/firebase_setup.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_core/data/repositories/announcement_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_announcement_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_menu_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_order_repository.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/data/services/auth_service.dart';
import 'package:breakbite_core/data/services/connectivity_service.dart';
import 'package:breakbite_core/data/services/firebase/firebase_analytics_service.dart';
import 'package:breakbite_core/data/services/firebase/firebase_auth_service.dart';
import 'package:breakbite_core/data/services/firebase/firebase_remote_config_service.dart';
import 'package:breakbite_core/data/services/remote_config_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// The web admin's data layer: the same repositories and services as the mobile app, from packages/core. Screens
/// and view models only see the interfaces, so tests swap in fakes ([adminProviders]).
Future<List<SingleChildWidget>> firebaseProviders() async {
  final db = FirebaseFirestore.instance;
  final remoteConfig = FirebaseRemoteConfigService(
    FirebaseRemoteConfig.instance,
    minimumFetchInterval: usingFirebaseEmulator ? Duration.zero : const Duration(hours: 1),
  );
  await remoteConfig.initialize();
  unawaited(remoteConfig.fetchAndActivate());
  return adminProviders(
    auth: FirebaseAuthService.web(auth: FirebaseAuth.instance, db: db),
    orders: FirestoreOrderRepository(db),
    menu: FirestoreMenuRepository(db),
    announcements: FirestoreAnnouncementRepository(db),
    analytics: FirebaseAnalyticsService(FirebaseAnalytics.instance),
    remoteConfig: remoteConfig,
    connectivity: BrowserConnectivityService(),
  );
}

List<SingleChildWidget> adminProviders({
  required AuthService auth,
  required OrderRepository orders,
  required MenuRepository menu,
  required AnnouncementRepository announcements,
  required AnalyticsService analytics,
  required RemoteConfigService remoteConfig,
  required ConnectivityService connectivity,
}) => [
  Provider<AuthService>.value(value: auth),
  Provider<OrderRepository>.value(value: orders),
  Provider<MenuRepository>.value(value: menu),
  Provider<AnnouncementRepository>.value(value: announcements),
  Provider<AnalyticsService>.value(value: analytics),
  Provider<RemoteConfigService>.value(value: remoteConfig),
  ChangeNotifierProvider<AdminSession>(
    create: (_) => AdminSession(auth: auth, menu: menu, analytics: analytics, connectivity: connectivity),
  ),
];
