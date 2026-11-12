import 'dart:async';

import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/data/services/analytics_events.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/data/services/auth_service.dart';
import 'package:breakbite_core/data/services/connectivity_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/app_user.dart';
import 'package:breakbite_core/domain/models/kiosk.dart';
import 'package:breakbite_core/domain/web_access.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// Who is signed in to the web admin and which kiosk they work on. Staff always work on their own kiosk; an
/// admin picks one from the top bar. A customer account is signed out at once with [rejection] as the reason
/// (W01, "reject non-staff accounts").
class AdminSession extends ChangeNotifier with SafeChangeNotifier {
  AdminSession({required this._auth, required this._menu, this._analytics, this._connectivity}) {
    signIn = Command0(_signIn);
    _authSub = _auth.authStateChanges().listen(_onUser, onError: _onAuthError);
    _onlineSub = _connectivity?.watchOnline().listen(_setOnline, onError: (Object _) {});
  }

  /// What every screen shows instead of its content while the browser has no network.
  static const offlineMessage =
      'Mất kết nối mạng. Dữ liệu trên trang có thể đã cũ và thao tác sẽ không được gửi. Kiểm tra Wi-Fi; trang tự tải '
      'lại khi có mạng.';

  final AuthService _auth;
  final MenuRepository _menu;
  final AnalyticsService? _analytics;
  final ConnectivityService? _connectivity;
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<bool>? _onlineSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;

  late final Command0<AppUser> signIn;

  bool _ready = false;
  bool _online = true;
  AppUser? _user;
  String? _rejection;
  List<Kiosk> _kiosks = const [];
  String? _pickedKioskId;

  /// False until Firebase says whether someone is signed in; the router waits on it.
  bool get ready => _ready;

  /// The signed-in staff member or admin; `null` when signed out or rejected.
  AppUser? get user => _user;
  bool get signedIn => _user != null;

  /// False while the browser is offline; the shell then shows [offlineMessage] instead of a screen whose Firestore
  /// data could only come from an empty or old cache.
  bool get online => _online;

  /// "Thử lại" on the offline state: asks the browser again.
  Future<void> checkConnection() async {
    final connectivity = _connectivity;
    if (connectivity != null) _setOnline(await connectivity.check());
  }

  void _setOnline(bool value) {
    if (value == _online) return;
    _online = value;
    notifyListeners();
  }

  bool get isAdmin => _user?.role == UserRole.admin;

  /// Why the last account was turned away, shown on the sign-in screen until the next attempt.
  String? get rejection => _rejection;

  /// Every kiosk, for the admin's picker.
  List<Kiosk> get kiosks => _kiosks;

  /// The kiosk every screen works on: the staff member's own, or the admin's choice (the first kiosk by default).
  String? get kioskId => isAdmin ? (_pickedKioskId ?? _kiosks.firstOrNull?.id) : _user?.kioskId;

  String get kioskName {
    final id = kioskId;
    return _kiosks.where((k) => k.id == id).firstOrNull?.name ?? id ?? '';
  }

  void selectKiosk(String id) {
    if (!isAdmin || id == kioskId) return;
    _pickedKioskId = id;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<Result<AppUser>> _signIn() async {
    _rejection = null;
    notifyListeners();
    final result = await _auth.signInWithGoogle();
    if (result case Ok(:final value)) {
      final problem = webAdminAccessProblem(value);
      if (problem != null) return Result.error(ValidationException(problem));
      unawaited(_analytics?.setUserId(value.uid));
      unawaited(_analytics?.logEvent(AnalyticsEvents.adminSignIn, {'role': value.role.name}));
    }
    return result;
  }

  void _onUser(AppUser? user) {
    _ready = true;
    if (user == null) {
      _user = null;
      _stopKiosks();
    } else {
      final problem = webAdminAccessProblem(user);
      if (problem != null) {
        _user = null;
        _rejection = problem;
        _stopKiosks();
        unawaited(_auth.signOut());
      } else {
        _user = user;
        _rejection = null;
        _watchKiosks();
      }
    }
    notifyListeners();
  }

  void _onAuthError(Object error) {
    _ready = true;
    _user = null;
    notifyListeners();
  }

  void _watchKiosks() {
    _kioskSub ??= _menu.watchKiosks().listen((kiosks) {
      _kiosks = kiosks;
      notifyListeners();
    }, onError: (Object _) {});
  }

  void _stopKiosks() {
    _kioskSub?.cancel();
    _kioskSub = null;
    _kiosks = const [];
    _pickedKioskId = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _kioskSub?.cancel();
    _onlineSub?.cancel();
    signIn.dispose();
    super.dispose();
  }
}
