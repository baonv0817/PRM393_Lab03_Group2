import 'package:breakbite/data/services/firebase/notification_inbox.dart';
import 'package:breakbite/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');

const firestoreEmulatorPort = 8080;
const authEmulatorPort = 9099;

bool get usingFirebaseEmulator => useFirebaseEmulator && kDebugMode;

Future<void> initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!usingFirebaseEmulator) return;
  final host = emulatorHost();
  FirebaseFirestore.instance.useFirestoreEmulator(host, firestoreEmulatorPort);
  await FirebaseAuth.instance.useAuthEmulator(host, authEmulatorPort);
}

/// The App Check debug token of a test phone or emulator, from `--dart-define-from-file=env/app_check.json`
/// (gitignored; see `env/app_check.example.json`). It is registered in the console under App Check > Apps >
/// Manage debug tokens, and must never be committed: anyone holding it passes App Check.
const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

/// App Check: every Firestore and AI Logic request then carries a token that proves it comes from this app.
/// A debug build, or any build given a debug token, uses the debug provider; other builds use Play Integrity.
/// A failure is logged, not thrown: while enforcement is off in the console the requests still go through.
Future<void> activateAppCheck() async {
  if (usingFirebaseEmulator) return;
  final useDebugProvider = kDebugMode || _appCheckDebugToken.isNotEmpty;
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: useDebugProvider
          ? AndroidDebugProvider(debugToken: _appCheckDebugToken.isEmpty ? null : _appCheckDebugToken)
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (error) {
    debugPrint('App Check was not activated: $error');
  }
}

void reportUncaughtErrors(FirebaseCrashlytics crashlytics) {
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initializeFirebase();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  try {
    await saveToInbox(FirebaseFirestore.instance, uid, message);
  } catch (error) {
    debugPrint('Background notification was not saved: $error');
  }
}

String emulatorHost() {
  if (_emulatorHost.isNotEmpty) return _emulatorHost;
  final onAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  return onAndroid ? '10.0.2.2' : 'localhost';
}
