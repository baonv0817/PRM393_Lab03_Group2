import 'dart:async';

import 'package:breakbite_admin/config/admin_providers.dart';
import 'package:breakbite_admin/config/browser_connectivity.dart';
import 'package:breakbite_admin/config/firebase_setup.dart';
import 'package:breakbite_admin/config/firebase_stats_insight_service.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/audit_writer.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/firestore_admin_incident_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/firestore_admin_kiosk_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/firestore_admin_order_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/firestore_admin_slot_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/firestore_admin_user_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/firestore_admin_voucher_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/admin/firestore_audit_log_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_announcement_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_menu_repository.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_order_repository.dart';
import 'package:breakbite_core/data/services/firebase/firebase_analytics_service.dart';
import 'package:breakbite_core/data/services/firebase/firebase_auth_service.dart';
import 'package:breakbite_core/data/services/firebase/firebase_remote_config_service.dart';
import 'package:breakbite_core/domain/models/audit_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:provider/single_child_widget.dart';

export 'package:breakbite_admin/config/admin_providers.dart';

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
  // Every change of the system pages carries the admin who made it, read when the change is written.
  AdminActor actor() {
    final user = FirebaseAuth.instance.currentUser;
    return AdminActor(uid: user?.uid ?? '', name: user?.displayName ?? user?.email ?? '');
  }

  final audit = AuditWriter(db, actor);
  return adminProviders(
    auth: FirebaseAuthService.web(auth: FirebaseAuth.instance, db: db),
    system: SystemRepositories(
      users: FirestoreAdminUserRepository(db, audit),
      kiosks: FirestoreAdminKioskRepository(db, audit),
      slots: FirestoreAdminSlotRepository(db, audit),
      vouchers: FirestoreAdminVoucherRepository(db, audit),
      orders: FirestoreAdminOrderRepository(db),
      incidents: FirestoreAdminIncidentRepository(db),
      audit: FirestoreAuditLogRepository(db),
    ),
    orders: FirestoreOrderRepository(db),
    menu: FirestoreMenuRepository(db),
    announcements: FirestoreAnnouncementRepository(db),
    analytics: FirebaseAnalyticsService(FirebaseAnalytics.instance),
    remoteConfig: remoteConfig,
    connectivity: BrowserConnectivityService(),
    insight: FirebaseStatsInsightService(),
  );
}
