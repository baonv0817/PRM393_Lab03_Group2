import 'package:firebase_core/firebase_core.dart';

/// The Firebase web app "BreakBite Admin" of project `breakbite-1315b`, registered on 12/11/2026 with
/// `firebase apps:create WEB "BreakBite Admin"`; the values come from `firebase apps:sdkconfig WEB <appId>`.
///
/// A web API key is not a secret: it only identifies the project, and the Security Rules and App Check protect the
/// data. Against the Firebase Emulator (`USE_FIREBASE_EMULATOR=true`) the same values work, because the Emulator does
/// not check them.
abstract final class DefaultFirebaseOptions {
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDZBzsQy55wCKDYg4-OI1WkuuKu0zyl8A4',
    appId: '1:652236973307:web:29f7ac880e23bdad3fbc5e',
    messagingSenderId: '652236973307',
    projectId: 'breakbite-1315b',
    authDomain: 'breakbite-1315b.firebaseapp.com',
    storageBucket: 'breakbite-1315b.firebasestorage.app',
    measurementId: 'G-5690JF2EHK',
  );
}
