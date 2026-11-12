import 'package:breakbite/data/services/firebase/notification_inbox.dart';
import 'package:breakbite/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
