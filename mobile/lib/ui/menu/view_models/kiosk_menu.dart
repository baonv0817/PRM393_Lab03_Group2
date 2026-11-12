import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';

class KioskMenu {
  KioskMenu({
    required this.menu,
    required this.session,
    required this.crash,
    required this._reason,
    required this._onChanged,
  });

  static const noKioskMessage = 'Chưa có kiosk nào đang hoạt động';
  static const loadErrorMessage = 'Không tải được thực đơn. Kiểm tra mạng rồi thử lại.';

  final MenuRepository menu;
  final SessionRepository session;
  final CrashService crash;
  final String _reason;
  final void Function() _onChanged;

  StreamSubscription<List<MenuItem>>? _menuSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  StreamSubscription<String?>? _sessionSub;
  List<Kiosk>? _kiosks;
  String? _selectedKioskId;
  bool _sessionKnown = false;
  Kiosk? _kiosk;
  List<MenuItem>? _items;
  String? _error;
  bool _noKiosk = false;

  Kiosk? get kiosk => _kiosk;
  List<MenuItem>? get items => _items;

  ViewState<List<MenuItem>> stateOf(
    List<MenuItem> Function(List<MenuItem> items) pick, {
    required String emptyMessage,
  }) {
    if (_error case final message?) return ViewError(message);
    if (_noKiosk) return const ViewEmpty(noKioskMessage);
    final items = _items;
    if (items == null) return const ViewLoading();
    return ViewStateX.fromList(pick(items), emptyMessage: emptyMessage);
  }

  void start() {
    stop();
    _kiosks = null;
    _sessionKnown = false;
    _kiosk = null;
    _items = null;
    _error = null;
    _noKiosk = false;
    _onChanged();
    _kioskSub = menu.watchKiosks().listen((kiosks) {
      _kiosks = kiosks;
      _applyKiosk();
    }, onError: (Object e, StackTrace s) => _fail(e, s, 'watchKiosks'));
    _sessionSub = session.watchSelectedKioskId().listen((id) {
      _selectedKioskId = id;
      _sessionKnown = true;
      _applyKiosk();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, '$_reason.watchSelectedKiosk'));
  }

  void stop() {
    unawaited(_menuSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_sessionSub?.cancel());
  }

  void _applyKiosk() {
    final kiosks = _kiosks;
    if (kiosks == null || !_sessionKnown) return;
    final chosen = kiosks.where((k) => k.id == _selectedKioskId).firstOrNull;
    final next = chosen ?? kiosks.where((k) => k.open).firstOrNull ?? kiosks.firstOrNull;
    if (chosen == null && next != null) unawaited(session.selectKiosk(next.id));
    final changed = next?.id != _kiosk?.id;
    _kiosk = next;
    _noKiosk = next == null;
    if (next == null) {
      unawaited(_menuSub?.cancel());
      _items = null;
    } else if (changed) {
      _watchMenu(next.id);
    }
    _onChanged();
  }

  void _watchMenu(String kioskId) {
    unawaited(_menuSub?.cancel());
    _items = null;
    _error = null;
    _menuSub = menu.watchMenu(kioskId).listen((items) {
      _items = items;
      _error = null;
      _onChanged();
    }, onError: (Object e, StackTrace s) => _fail(e, s, 'watchMenu'));
  }

  void _fail(Object error, StackTrace stack, String what) {
    crash.recordNonFatal(error, stack, '$_reason.$what');
    _error = error is AppException ? error.message : loadErrorMessage;
    _onChanged();
  }
}
