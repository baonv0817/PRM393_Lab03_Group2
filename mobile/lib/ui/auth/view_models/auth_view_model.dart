import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/mobile_access.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

class AuthViewModel extends ChangeNotifier with SafeChangeNotifier {
  AuthViewModel(this._auth, this._analytics, this._crash, this._session, this._messaging) {
    _sub = _auth.authStateChanges().listen(
      (signedIn) {
        // An admin account is turned away with the reason (the web admin is theirs) and signed out at once.
        final problem = signedIn == null ? null : mobileAccessProblem(signedIn);
        if (problem != null) {
          _message = problem;
          unawaited(_auth.signOut());
        }
        final user = problem == null ? signedIn : null;
        final previous = _user;
        _user = user;
        _initialized = true;
        if (user?.uid != previous?.uid || user?.role != previous?.role || user?.kioskId != previous?.kioskId) {
          unawaited(_onUserChanged(previous, user));
        }
        notifyListeners();
      },
      onError: (Object e, StackTrace s) {
        _initialized = true;
        _message = 'Không kiểm tra được trạng thái đăng nhập. Kiểm tra mạng rồi mở lại ứng dụng.';
        _crash.recordNonFatal(e, s, 'auth.authStateChanges');
        notifyListeners();
      },
    );
    _kioskSub = _session.watchSelectedKioskId().listen((id) {
      _selectedKioskId = id;
      if (_user != null) unawaited(_syncKioskKey());
    }, onError: (Object e, StackTrace s) => _crash.recordNonFatal(e, s, 'auth.watchSelectedKiosk'));
  }

  final AuthService _auth;
  final AnalyticsService _analytics;
  final CrashService _crash;
  final SessionRepository _session;
  final MessagingService _messaging;
  late final StreamSubscription<AppUser?> _sub;
  late final StreamSubscription<String?> _kioskSub;
  String? _selectedKioskId;

  late final signIn = Command0<AppUser>(_signIn);

  late final signOut = Command0<void>(_signOut);

  AppUser? _user;
  bool _initialized = false;
  bool _onboardingDone = false;
  String? _message;

  AppUser? get user => _user;

  bool get initialized => _initialized;

  bool get onboardingDone => _onboardingDone;

  String? get message => _message;

  void completeOnboarding() {
    if (_onboardingDone) return;
    _onboardingDone = true;
    notifyListeners();
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  Future<Result<AppUser>> _signIn() async {
    _message = null;
    notifyListeners();
    final result = await _auth.signInWithGoogle();
    switch (result) {
      case Ok(:final value) when mobileAccessProblem(value) != null:
        final problem = mobileAccessProblem(value)!;
        _message = problem;
        notifyListeners();
        return Result.error(PermissionDeniedException(message: problem));
      case Ok():
        await _analytics.logEvent(AnalyticsEvents.login, {'method': 'google'});
      case Err(error: CancelledException()):
        _message = 'Bạn đã huỷ đăng nhập. Chọn tài khoản Google để tiếp tục.';
      case Err(:final error):
        _message = error.message;
        _crash.recordNonFatal(error, error.stackTrace, 'auth.signInWithGoogle');
    }
    notifyListeners();
    return result;
  }

  Future<Result<void>> _signOut() async {
    final uid = _user?.uid;
    // Housekeeping first, each with a time limit: a slow or unreachable service (analytics, the push token
    // in Firestore) must never keep the person signed in with a button stuck on "Đang đăng xuất…".
    await _bestEffort(_analytics.logEvent(AnalyticsEvents.logout));
    if (uid != null) await _bestEffort(_messaging.detachUser(uid));
    final result = await _auth.signOut();
    switch (result) {
      case Ok():
        await _session.clear();
      case Err(:final error):
        _message = error.message;
        _crash.recordNonFatal(error, error.stackTrace, 'auth.signOut');
        notifyListeners();
    }
    return result;
  }

  /// How long sign-out waits for a service that is only housekeeping.
  static const _housekeepingLimit = Duration(seconds: 4);

  /// Waits for [work] at most [_housekeepingLimit] and never throws: a failure here is recorded, not shown.
  Future<void> _bestEffort(Future<void> work) async {
    try {
      await work.timeout(_housekeepingLimit);
    } catch (error, stack) {
      _crash.recordNonFatal(error, stack, 'auth.signOut.housekeeping');
    }
  }

  Future<void> _onUserChanged(AppUser? previous, AppUser? user) async {
    if (user == null) {
      await _analytics.setUserId(null);
      return;
    }
    if (previous?.uid != user.uid) {
      if (user.defaultKioskId case final kioskId?) await _session.selectKiosk(kioskId);
      await _analytics.setUserId(user.uid);
      await _crash.setUserId(user.uid);
      await _messaging.attachUser(user.uid);
      await _messaging.requestPermission();
    }
    await _crash.setKey('role', user.role.name);
    await _syncKioskKey();
  }

  Future<void> _syncKioskKey() => _crash.setKey('kiosk_id', _user?.kioskId ?? _selectedKioskId ?? 'none');

  @override
  void dispose() {
    unawaited(_sub.cancel());
    unawaited(_kioskSub.cancel());
    signIn.dispose();
    signOut.dispose();
    super.dispose();
  }
}
