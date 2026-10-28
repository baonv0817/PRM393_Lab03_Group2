import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/services.dart';

/// Trạng thái đăng nhập của cả app. Router lắng nghe để định tuyến theo auth.
/// Mẫu cho ViewModel: nhận service qua constructor, không gọi SDK, kiểm thử được bằng service giả.
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
  String? _message;

  AppUser? get user => _user;

  /// Đã biết trạng thái đăng nhập lần đầu (để router không đẩy người dùng đi nhầm).
  bool get initialized => _initialized;
  bool get busy => _busy;

  /// Thông báo lỗi hoặc huỷ để màn đăng nhập hiển thị.
  String? get message => _message;

  Future<void> signIn() async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _auth.signInWithGoogle();
    } on AuthCancelled {
      _message = 'Bạn đã huỷ đăng nhập.';
    } on AuthFailure catch (e) {
      _message = e.message;
      unawaited(_crash.recordError(e, null, reason: 'signInWithGoogle'));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _analytics.logEvent('logout');
    await _auth.signOut();
  }

  Future<void> _onUserChanged(AppUser? user) async {
    await _analytics.setUserId(user?.uid);
    if (user != null) {
      await _crash.setUserId(user.uid);
      await _analytics.logEvent('login', {'method': 'google'});
    }
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
