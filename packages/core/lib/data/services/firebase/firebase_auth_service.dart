import 'dart:async';

import 'package:breakbite_core/data/firebase/firebase_errors.dart';
import 'package:breakbite_core/data/firebase/firestore_helpers.dart';
import 'package:breakbite_core/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite_core/data/services/auth_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/app_user.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/streams.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

typedef GoogleIdTokenSource = Future<String?> Function();

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    required this._auth,
    required this._db,
    GoogleSignIn? google,
    this._googleIdToken,
    this._webPopup = false,
  }) : _google = google ?? GoogleSignIn.instance;

  /// The web admin signs in with Firebase's Google pop-up; the mobile app uses the google_sign_in account picker.
  FirebaseAuthService.web({required FirebaseAuth auth, required FirebaseFirestore db})
    : this(auth: auth, db: db, webPopup: true);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _google;
  final GoogleIdTokenSource? _googleIdToken;
  final bool _webPopup;
  final _profiles = <String, Future<void>>{};
  Future<void>? _googleReady;

  DocumentReference<Json> _profile(String uid) => _db.collection('users').doc(uid);

  @override
  Stream<AppUser?> authStateChanges() => guardStream(
    _auth.authStateChanges().switchMap((user) {
      if (user == null) return Stream<AppUser?>.value(null);
      return Stream.fromFuture(_ensureProfileOnce(user)).asyncExpand(
        (_) =>
            _profile(user.uid)
                .snapshots()
                .map<AppUser?>((snapshot) => _toAppUser(user, snapshot.data()))
                .handleError((Object error, StackTrace stack) {
                  if (_auth.currentUser?.uid == user.uid) Error.throwWithStackTrace(error, stack);
                }),
      );
    }),
  );

  @override
  Future<Result<AppUser>> signInWithGoogle() => guard(() async {
    final credential = _webPopup
        ? await _auth.signInWithPopup(GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}))
        : await _signInWithIdToken();
    final user = credential.user;
    if (user == null) throw const ServiceException(message: 'Không đăng nhập được. Thử lại sau.');
    try {
      await _ensureProfileOnce(user, required: true);
      final snapshot = await _profile(user.uid).get();
      return _toAppUser(user, snapshot.data());
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  });

  @override
  Future<Result<AppUser>> signInWithEmail(String email, String password) => guard(() async {
    final credential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return _finishSignIn(credential.user);
  });

  @override
  Future<Result<AppUser>> registerWithEmail({required String name, required String email, required String password}) =>
      guard(() async {
        final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        final user = credential.user;
        if (user == null) throw const ServiceException(message: 'Không tạo được tài khoản. Thử lại sau.');
        try {
          await user.updateDisplayName(name.trim());
          await _ensureProfileOnce(user, required: true);
          // The profile may have been made, by the sign-in listener, before the name was set: write the name.
          await _profile(user.uid).update({'displayName': name.trim(), ...Stamp.updated()});
          final snapshot = await _profile(user.uid).get();
          return _toAppUser(user, snapshot.data());
        } catch (_) {
          await _auth.signOut();
          rethrow;
        }
      });

  Future<AppUser> _finishSignIn(User? user) async {
    if (user == null) throw const ServiceException(message: 'Không đăng nhập được. Thử lại sau.');
    try {
      await _ensureProfileOnce(user, required: true);
      final snapshot = await _profile(user.uid).get();
      return _toAppUser(user, snapshot.data());
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  @override
  Future<Result<void>> signOut() => guard(() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) _profiles.remove(uid)?.ignore();
    // Firebase first: it is what ends the session. Google's own sign-out only forgets the account choice;
    // on a device whose credential service does not answer it can hang, so it runs on its own with a limit.
    await _auth.signOut();
    if (_googleIdToken == null && !_webPopup) unawaited(_signOutGoogle());
  });

  Future<void> _signOutGoogle() async {
    try {
      await _ensureGoogle();
      await _google.signOut().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best effort: the Firebase session is already gone.
    }
  }

  AppUser _toAppUser(User user, Json? data) =>
      appUserFromData(user.uid, data, fallbackName: _displayNameOf(user), email: user.email, photoUrl: user.photoURL);

  String _displayNameOf(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Khách';
  }

  Future<UserCredential> _signInWithIdToken() async {
    final idToken = await (_googleIdToken ?? _idTokenFromGoogle)();
    if (idToken == null || idToken.isEmpty) {
      throw const ServiceException(message: 'Google không trả về thông tin đăng nhập. Thử lại sau.');
    }
    return _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  Future<void> _ensureGoogle() => _googleReady ??= _google.initialize();

  Future<String?> _idTokenFromGoogle() async {
    await _ensureGoogle();
    final account = await _google.authenticate();
    return account.authentication.idToken;
  }

  Future<void> _ensureProfileOnce(User user, {bool required = false}) {
    final pending = _profiles[user.uid] ??= _ensureProfile(user);
    return pending.catchError((Object error) {
      _profiles.remove(user.uid);
      if (required) throw toAppException(error);
    });
  }

  Future<void> _ensureProfile(User user) async {
    final ref = _profile(user.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) {
      unawaited(
        ref.update({'lastLoginAt': FieldValue.serverTimestamp(), ...Stamp.updated()}).catchError((Object _) {}),
      );
      return;
    }
    await ref.set({
      'displayName': _displayNameOf(user),
      'email': user.email ?? '',
      'photoUrl': ?user.photoURL,
      'role': UserRole.user.name,
      'lastLoginAt': FieldValue.serverTimestamp(),
      ...Stamp.created(),
    });
  }
}
