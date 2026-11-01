import 'dart:async';

import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/config/firebase_setup.dart';
import 'package:breakbite/data/repositories/firestore/firestore_cart_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_menu_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_order_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_report_repository.dart';
import 'package:breakbite/data/repositories/firestore/firestore_user_repository.dart';
import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/data/services/cloudinary/cloudinary_storage_service.dart';
import 'package:breakbite/data/services/firebase/firebase_analytics_service.dart';
import 'package:breakbite/data/services/firebase/firebase_auth_service.dart';
import 'package:breakbite/data/services/firebase/firebase_crash_service.dart';
import 'package:breakbite/data/services/firebase/firebase_messaging_service.dart';
import 'package:breakbite/data/services/firebase/firebase_remote_config_service.dart';
import 'package:breakbite/data/services/pdf/pdf_report_file_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

Future<AppDependencies> createFirebaseDependencies() async {
  await initializeFirebase();
  final crashlytics = FirebaseCrashlytics.instance;
  reportUncaughtErrors(crashlytics);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final db = FirebaseFirestore.instance;
  final remoteConfig = FirebaseRemoteConfigService(
    FirebaseRemoteConfig.instance,
    minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
  );
  await remoteConfig.initialize();
  unawaited(remoteConfig.fetchAndActivate());

  return AppDependencies(
    auth: FirebaseAuthService(auth: FirebaseAuth.instance, db: db),
    analytics: FirebaseAnalyticsService(FirebaseAnalytics.instance),
    crash: FirebaseCrashService(crashlytics),
    messaging: FirebaseMessagingService(messaging: FirebaseMessaging.instance, db: db),
    storage: CloudinaryStorageService(CloudinaryConfig.fromEnvironment()),
    remoteConfig: remoteConfig,
    reportFiles: PdfReportFileService(),
    menu: FirestoreMenuRepository(db),
    cart: FirestoreCartRepository(db),
    orders: FirestoreOrderRepository(db),
    reports: FirestoreReportRepository(db),
    session: InMemorySessionRepository(),
    users: FirestoreUserRepository(db),
  );
}
