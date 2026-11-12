import 'package:breakbite_admin/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// `--dart-define=USE_FIREBASE_EMULATOR=true` points a debug build at the local Auth and Firestore emulators
/// (`firebase emulators:start` in firebase/). A release build always uses the real project.
const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

bool get usingFirebaseEmulator => useFirebaseEmulator && kDebugMode;

Future<void> initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  if (!usingFirebaseEmulator) return;
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
}
