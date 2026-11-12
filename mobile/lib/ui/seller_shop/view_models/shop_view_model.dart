import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// K10: the shop of the staff member's kiosk. The switch, the pause and the wait take effect at once (a
/// customer sees them in the next second); the notice, the hours and the slot capacity are typed in a form
/// and saved with a button.
class ShopViewModel extends ChangeNotifier with SafeChangeNotifier {
  ShopViewModel({required this.menu, required this.crash, required this.kioskId, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    saveInfo = Command0(_saveInfo);
    load();
  }

  static const noKioskMessage =
      'Tài khoản này chưa được gán kiosk nên chưa có quán để quản lý. Nhờ quản trị viên gán kiosk cho bạn.';
  static const notFoundMessage = 'Không tìm thấy kiosk của bạn.';
  static const invalidMessage = 'Kiểm tra lại các ô báo lỗi.';
  static const maxOrdersLimit = 999;

  /// The "tạm ngưng" shortcuts.
  static const pauseChoices = [Duration(minutes: 15), Duration(minutes: 30), Duration(hours: 1)];

  final MenuRepository menu;
  final CrashService crash;
  final String? kioskId;
  final DateTime Function() _clock;

  StreamSubscription<List<Kiosk>>? _sub;
  ViewState<Kiosk> _state = const ViewLoading();
  bool _formLoaded = false;
  bool _tried = false;
  bool _applying = false;
  String _notice = '';
  String _openTime = '';
  String _closeTime = '';
  String _maxOrders = '';

  /// Saves the notice, hours and capacity.
  late final Command0<void> saveInfo;

  ViewState<Kiosk> get state => _state;
  DateTime get now => _clock();

  Kiosk? get kiosk => _state.dataOrNull;

  /// A switch, pause or wait change is being written.
  bool get applying => _applying;

  bool get hasKiosk => kioskId != null && kioskId!.isNotEmpty;

  void load() {
    unawaited(_sub?.cancel());
    final id = kioskId;
    if (id == null || id.isEmpty) {
      _state = const ViewEmpty(noKioskMessage);
      notifyListeners();
      return;
    }
    _state = const ViewLoading();
    notifyListeners();
    _sub = menu.watchKiosks().listen(
      (kiosks) {
        final found = kiosks.where((k) => k.id == id).firstOrNull;
        if (found == null) {
          _state = const ViewEmpty(notFoundMessage);
        } else {
          _state = ViewData(found);
          if (!_formLoaded) _fillForm(found);
        }
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        crash.recordNonFatal(error, stack, 'shop.watchKiosks');
        _state = ViewError(error is AppException ? error.message : 'Không tải được thông tin quán.');
        notifyListeners();
      },
    );
  }

  void _fillForm(Kiosk kiosk) {
    _formLoaded = true;
    _notice = kiosk.notice ?? '';
    _openTime = kiosk.openTime ?? '';
    _closeTime = kiosk.closeTime ?? '';
    _maxOrders = kiosk.maxOrdersPerSlot?.toString() ?? '';
  }

  // ---- Status: the switch, the pause and the wait ----

  bool get isPaused {
    final until = kiosk?.pausedUntil;
    return until != null && until.isAfter(now);
  }

  /// "Mở · chờ 5–7 phút", "Tạm ngưng · nhận đơn lại lúc 10:30" or "Đang đóng cửa".
  String get statusLine => kiosk == null ? '' : kioskStatusLabel(kiosk!, now: now);

  bool get acceptsOrders => kiosk?.acceptsOrders(now) ?? false;

  int get waitMinutes => kiosk?.waitMinutes ?? 0;

  bool get canLowerWait => waitMinutes > 0;

  bool get canRaiseWait => waitMinutes < KioskSettings.maxWaitMinutes;

  /// Closing the kiosk also drops a pause, which would mean nothing on a closed kiosk.
  Future<Result<void>> setOpen(bool open) =>
      _apply((s) => s.copyWith(open: open, pausedUntil: open ? s.pausedUntil : null));

  Future<Result<void>> pauseFor(Duration duration) =>
      _apply((s) => s.copyWith(open: true, pausedUntil: now.add(duration)));

  Future<Result<void>> resume() => _apply((s) => s.copyWith(pausedUntil: null));

  Future<Result<void>> changeWait(int delta) {
    final next = (waitMinutes + delta).clamp(0, KioskSettings.maxWaitMinutes);
    return _apply((s) => s.copyWith(waitMinutes: next));
  }

  /// Writes the settings the kiosk has now, changed by [change]. One write at a time, so that two quick taps
  /// cannot overwrite each other with stale values.
  Future<Result<void>> _apply(KioskSettings Function(KioskSettings current) change) async {
    final current = kiosk;
    if (current == null || _applying) return const Result.ok(null);
    _applying = true;
    notifyListeners();
    try {
      final result = await menu.updateKiosk(current.id, change(KioskSettings.of(current)));
      if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'shop.updateKiosk');
      return result;
    } finally {
      _applying = false;
      notifyListeners();
    }
  }

  // ---- Info form: notice, hours, capacity ----

  String get notice => _notice;
  String get openTime => _openTime;
  String get closeTime => _closeTime;
  String get maxOrders => _maxOrders;

  void setNotice(String value) => _edit(() => _notice = value);
  void setOpenTime(String value) => _edit(() => _openTime = value.trim());
  void setCloseTime(String value) => _edit(() => _closeTime = value.trim());
  void setMaxOrders(String value) => _edit(() => _maxOrders = value.trim());

  void _edit(void Function() change) {
    change();
    notifyListeners();
  }

  String? get noticeError =>
      _notice.trim().length > KioskSettings.maxNoticeLength ? 'Tối đa ${KioskSettings.maxNoticeLength} ký tự.' : null;

  String? get openTimeError => _timeError(_openTime);
  String? get closeTimeError => _timeError(_closeTime);

  String? _timeError(String value) => value.isEmpty || KioskSettings.isClockTime(value) ? null : 'Nhập giờ dạng 06:30.';

  String? get maxOrdersError {
    if (_maxOrders.isEmpty) return null;
    final n = int.tryParse(_maxOrders);
    if (n == null || n < 1 || n > maxOrdersLimit) return 'Nhập số từ 1 đến $maxOrdersLimit, hoặc để trống.';
    return null;
  }

  /// Errors appear once the staff member has tried to save.
  bool get showErrors => _tried;

  bool get infoValid =>
      noticeError == null && openTimeError == null && closeTimeError == null && maxOrdersError == null;

  /// The form differs from what the kiosk has now.
  bool get infoDirty {
    final k = kiosk;
    if (k == null) return false;
    return _notice.trim() != (k.notice ?? '') ||
        _openTime != (k.openTime ?? '') ||
        _closeTime != (k.closeTime ?? '') ||
        _maxOrders != (k.maxOrdersPerSlot?.toString() ?? '');
  }

  Future<Result<void>> _saveInfo() async {
    _tried = true;
    notifyListeners();
    final current = kiosk;
    if (current == null) return const Result.error(NotFoundException(message: notFoundMessage));
    if (!infoValid) return const Result.error(ValidationException(invalidMessage));
    final result = await menu.updateKiosk(
      current.id,
      KioskSettings.of(current).copyWith(
        notice: _notice.trim().isEmpty ? null : _notice.trim(),
        openTime: _openTime.isEmpty ? null : _openTime,
        closeTime: _closeTime.isEmpty ? null : _closeTime,
        maxOrdersPerSlot: _maxOrders.isEmpty ? null : int.parse(_maxOrders),
      ),
    );
    switch (result) {
      case Ok():
        _tried = false;
        _notice = _notice.trim();
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'shop.saveInfo');
    }
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    saveInfo.dispose();
    super.dispose();
  }
}
