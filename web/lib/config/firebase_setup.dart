import 'package:breakbite_admin/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// `--dart-define=USE_FIREBASE_EMULATOR=true` points a debug build at the local Auth and Firestore emulators
/// (`firebase emulators:start` in firebase/). A release build always uses the real project.
const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

/// The score-based reCAPTCHA Enterprise key "BreakBite Admin web (App Check)" of project breakbite-1315b
/// (domains: breakbite-1315b.web.app, breakbite-1315b.firebaseapp.com, localhost), registered for this web app in
/// App Check on 12/11/2026. App Check no longer accepts new reCAPTCHA v3 setups, so the web uses Enterprise. A site
/// key is public: every visitor's browser receives it.
const recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY', defaultValue: _registeredSiteKey);
const _registeredSiteKey = '6LesBB0uAAAAAOuk061cTW59eTawLmi4WbL19v9l';

/// A debug token registered in App Check (Manage debug tokens), for a debug build on a machine where reCAPTCHA
/// cannot score the browser. Never committed: pass it with `--dart-define=APP_CHECK_DEBUG_TOKEN=...`.
const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

bool get usingFirebaseEmulator => useFirebaseEmulator && kDebugMode;

Future<void> initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  if (!usingFirebaseEmulator) return;
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
}

/// App Check for the web admin: every Firestore request carries a token that proves it comes from this site
/// (reCAPTCHA Enterprise), so the console can enforce App Check on Firestore for both clients. Called after
/// [initializeFirebase] and before the first Firestore read. Skipped against the Emulator.
Future<void> activateAppCheck() async {
  if (usingFirebaseEmulator) return;
  final WebProvider provider;
  if (kDebugMode && _appCheckDebugToken.isNotEmpty) {
    provider = WebDebugProvider(debugToken: _appCheckDebugToken);
  } else if (recaptchaSiteKey.isNotEmpty) {
    provider = ReCaptchaEnterpriseProvider(recaptchaSiteKey);
  } else {
    debugPrint('App Check is off: no reCAPTCHA site key (RECAPTCHA_SITE_KEY).');
    return;
  }
  try {
    await FirebaseAppCheck.instance.activate(providerWeb: provider);
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  } catch (error) {
    debugPrint('App Check was not activated: $error');
  }
}
