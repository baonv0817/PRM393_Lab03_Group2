import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// App-wide sign-in state; the router listens to it to route by auth state.
/// Reference ViewModel: dependencies come through the constructor, actions are [Command]s, no SDK
/// calls, testable with fakes.
class AuthViewModel extends ChangeNotifier with SafeChangeNotifier {
  AuthViewModel(this._auth, this._analytics, this._crash, this._session) {
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
  final SessionRepository _session;
  late final StreamSubscription<AppUser?> _sub;

  /// Google sign-in (S26). `signIn.running` disables the button; failures set [message].
  late final signIn = Command0<AppUser>(_signIn);

  /// Signs out and clears the data kept on this device (the handout requires it).
  late final signOut = Command0<void>(_signOut);

  AppUser? _user;
  bool _initialized = false;
  bool _onboardingDone = false;
  String? _message;

  AppUser? get user => _user;

  /// The first auth state is known, so the router does not send the user to the wrong place.
  bool get initialized => _initialized;

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

  Future<Result<AppUser>> _signIn() async {
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
    notifyListeners();
    return result;
  }

  Future<Result<void>> _signOut() async {
    await _analytics.logEvent(AnalyticsEvents.logout);
    final result = await _auth.signOut();
    switch (result) {
      case Ok():
        await _session.clear();
      case Err(:final error):
        _message = error.message;
        unawaited(_crash.recordError(error.cause ?? error, error.stackTrace, reason: 'signOut'));
        notifyListeners();
    }
    return result;
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
    signIn.dispose();
    signOut.dispose();
    super.dispose();
  }
}
