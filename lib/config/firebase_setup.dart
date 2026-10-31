import 'package:breakbite/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// `--dart-define=USE_FIREBASE_EMULATOR=true` points Auth and Firestore at the local Emulator Suite
/// (`firebase emulators:start`, see `docs/setup.md`), so rules and flows can be tried and ARTEMIS can
/// run without touching the real project. Only honoured in debug builds.
const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Host of the Emulator Suite. Defaults to `10.0.2.2` on the Android emulator (the host machine) and
/// `localhost` elsewhere; a physical phone needs the computer's LAN address.
const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');

/// Ports from `firebase.json`.
const firestoreEmulatorPort = 8080;
const authEmulatorPort = 9099;

/// Initializes Firebase for this platform and, when asked, connects to the emulators. Call once,
/// before any Firebase service is used.
Future<void> initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!useFirebaseEmulator || !kDebugMode) return;
  final host = emulatorHost();
  FirebaseFirestore.instance.useFirestoreEmulator(host, firestoreEmulatorPort);
  await FirebaseAuth.instance.useAuthEmulator(host, authEmulatorPort);
}

String emulatorHost() {
  if (_emulatorHost.isNotEmpty) return _emulatorHost;
  final onAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  return onAndroid ? '10.0.2.2' : 'localhost';
}
