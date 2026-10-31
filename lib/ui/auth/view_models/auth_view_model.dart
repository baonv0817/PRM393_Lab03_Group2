import 'dart:async';

import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/foundation.dart';

/// App-wide sign-in state; the router listens to it to route by auth state.
/// Reference ViewModel: services come through the constructor, no SDK calls, testable with fakes.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._auth, this._analytics, this._crash) {
    _sub = _auth.authStateChanges().listen(
      (user) {
        final changed = user?.uid != _user?.uid;
        _user = user;
        _initialized = true;
        if (changed) unawaited(_onUserChanged(user));
        notifyListeners();
      },
      onError: (Object e, StackTrace s) {
        _initialized = true;
        _message = 'Không kiểm tra được trạng thái đăng nhập.';
        unawaited(_crash.recordError(e, s, reason: 'authStateChanges'));
        notifyListeners();
      },
    );
  }

  final AuthService _auth;
  final AnalyticsService _analytics;
  final CrashService _crash;
  late final StreamSubscription<AppUser?> _sub;

  AppUser? _user;
  bool _initialized = false;
  bool _busy = false;
  bool _onboardingDone = false;
  String? _message;

  AppUser? get user => _user;

  /// The first auth state is known, so the router does not send the user to the wrong place.
  bool get initialized => _initialized;
  bool get busy => _busy;

  /// Onboarding (S01) was completed in this session. Signed-out users see S01 before sign-in;
  /// signed-in users never see it.
  bool get onboardingDone => _onboardingDone;

  void completeOnboarding() {
    if (_onboardingDone) return;
    _onboardingDone = true;
    notifyListeners();
  }

  /// Error or cancellation message for the sign-in screen.
  String? get message => _message;

  Future<void> signIn() async {
    _busy = true;
    _message = null;
    notifyListeners();
    final result = await _auth.signInWithGoogle();
    switch (result) {
      case Ok():
        break;
      case Err(error: CancelledException()):
        _message = 'Bạn đã huỷ đăng nhập.';
      case Err(:final error):
        _message = error.message;
        unawaited(_crash.recordError(error.cause ?? error, error.stackTrace, reason: 'signInWithGoogle'));
    }
    _busy = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _analytics.logEvent(AnalyticsEvents.logout);
    final result = await _auth.signOut();
    if (result case Err(:final error)) {
      _message = error.message;
      unawaited(_crash.recordError(error.cause ?? error, error.stackTrace, reason: 'signOut'));
      notifyListeners();
    }
  }

  Future<void> _onUserChanged(AppUser? user) async {
    await _analytics.setUserId(user?.uid);
    if (user != null) {
      await _crash.setUserId(user.uid);
      await _analytics.logEvent(AnalyticsEvents.login, {'method': 'google'});
    }
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
