import 'package:firebase_core/firebase_core.dart';

/// The Firebase web app of project `breakbite-1315b`.
///
/// `flutterfire configure --project breakbite-1315b --platforms web --out lib/firebase_options.dart` (run in
/// `web/` after `firebase login`) replaces this file with the registered web app. Until then the values come
/// from `--dart-define` (see web/README.md), and the defaults only work against the Firebase Emulator, which does
/// not check the API key or the app id. A web API key is not a secret: the Security Rules and App Check protect
/// the data.
abstract final class DefaultFirebaseOptions {
  static const web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: 'emulator-only'),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: '1:652236973307:web:emulator-only'),
    messagingSenderId: '652236973307',
    projectId: 'breakbite-1315b',
    authDomain: 'breakbite-1315b.firebaseapp.com',
    storageBucket: 'breakbite-1315b.firebasestorage.app',
  );
}
