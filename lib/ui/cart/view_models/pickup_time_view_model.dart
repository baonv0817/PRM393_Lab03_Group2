import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

enum SlotProblem { full, tooSoon }

class PickupDay {
  const PickupDay(this.label, this.slots);

  final String label;
  final List<PickupSlot> slots;
}

class PickupTimeViewModel extends ChangeNotifier with SafeChangeNotifier {
  PickupTimeViewModel({
    required this.slots,
    required this.cart,
    required this.menu,
    required this.remoteConfig,
    required this.crash,
    required this.uid,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    confirm = Command0(_confirm);
    load();
  }

  static const noSlotsMessage = 'Kiosk chưa mở giờ hẹn nào sắp tới';
  static const _weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];

  final SlotRepository slots;
  final CartRepository cart;
  final MenuRepository menu;
  final RemoteConfigService remoteConfig;
  final CrashService crash;
  final String uid;
  final DateTime Function() _clock;

  late final Command0<void> confirm;

  StreamSubscription<Cart>? _cartSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  StreamSubscription<List<PickupSlot>>? _slotSub;
  Cart? _cart;
  List<Kiosk>? _kiosks;
  String? _watchedKioskId;
  List<PickupSlot>? _slots;
  String? _loadError;
  String? _selectedId;
  bool _touched = false;

  DateTime get now => _clock();
  bool get enabled => remoteConfig.getBool(RemoteKeys.pickupSlotEnabled);
  String? get selectedId => _selectedId;

  Kiosk? get kiosk {
    final id = _cart?.kioskId;
    return id == null ? null : _kiosks?.where((k) => k.id == id).firstOrNull;
  }

  int get waitMinutes => kiosk?.waitMinutes ?? 0;

  String get asapLabel => 'Sớm nhất · khoảng $waitMinutes phút nữa';

  ViewState<List<PickupDay>> get state {
    if (_loadError case final message?) return ViewError(message);
    final current = _cart;
    if (current == null) return const ViewLoading();
    if (current.isEmpty) return const ViewEmpty('Giỏ hàng đang trống, chưa cần hẹn giờ nhận.');
    final list = _slots;
    if (list == null) return const ViewLoading();
    return ViewData(_byDay(list));
  }

  List<PickupDay> _byDay(List<PickupSlot> list) {
    final days = <DateTime, List<PickupSlot>>{};
    for (final slot in list) {
      final local = slot.startAt.toLocal();
      days.putIfAbsent(DateTime(local.year, local.month, local.day), () => []).add(slot);
    }
    return [for (final entry in days.entries) PickupDay(_dayLabel(entry.key), entry.value)];
  }

  String _dayLabel(DateTime day) {
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Ngày mai';
    return '${_weekdays[day.weekday - 1]} ${formatDayMonth(day)}';
  }

  SlotProblem? problemOf(PickupSlot slot) {
    if (slot.isFull) return SlotProblem.full;
    if (slot.startAt.isBefore(now.add(Duration(minutes: waitMinutes)))) return SlotProblem.tooSoon;
    return null;
  }

  String slotNote(PickupSlot slot) => switch (problemOf(slot)) {
    SlotProblem.full => 'Đã đủ',
    SlotProblem.tooSoon => 'Không kịp',
    null when slot.remaining <= 3 => 'Còn ${slot.remaining} chỗ',
    null => '',
  };

  String get summary {
    final id = _selectedId;
    final slot = id == null ? null : _slots?.where((s) => s.id == id).firstOrNull;
    if (slot == null) return 'Món sẵn sàng khoảng ${formatTime(now.add(Duration(minutes: waitMinutes)))}.';
    return 'Nhận lúc ${formatTime(slot.startAt)}–${formatTime(slot.endAt)}, kiosk giữ món cho bạn trong khung này.';
  }

  bool get canConfirm => enabled && !confirm.running && state is ViewData<List<PickupDay>>;

  void load() {
    unawaited(_cartSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_slotSub?.cancel());
    _watchedKioskId = null;
    _loadError = null;
    _cart = null;
    _slots = null;
    notifyListeners();
    _kioskSub = menu.watchKiosks().listen((value) {
      _kiosks = value;
      notifyListeners();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'pickupTime.watchKiosks'));
    _cartSub = cart.watchCart(uid).listen((value) {
      _cart = value;
      if (!_touched) _selectedId = value.pickupSlotId;
      final kioskId = value.kioskId;
      if (kioskId != null && kioskId != _watchedKioskId) _watchSlots(kioskId);
      notifyListeners();
    }, onError: _onError);
  }

  void _watchSlots(String kioskId) {
    unawaited(_slotSub?.cancel());
    _watchedKioskId = kioskId;
    _slots = null;
    _slotSub = slots.watchUpcomingSlots(kioskId, from: now).listen((value) {
      _slots = value;
      notifyListeners();
    }, onError: _onError);
  }

  void _onError(Object error, StackTrace stack) {
    crash.recordNonFatal(error, stack, 'pickupTime.load');
    _loadError = error is AppException ? error.message : 'Không tải được giờ nhận.';
    notifyListeners();
  }

  void chooseAsap() {
    _touched = true;
    _selectedId = null;
    notifyListeners();
  }

  void choose(PickupSlot slot) {
    if (problemOf(slot) != null) return;
    _touched = true;
    _selectedId = slot.id;
    notifyListeners();
  }

  Future<Result<void>> _confirm() async {
    final id = _selectedId;
    final slot = id == null ? null : _slots?.where((s) => s.id == id).firstOrNull;
    if (slot != null && problemOf(slot) != null) {
      return const Result.error(
        ValidationException('Khung giờ này vừa hết chỗ hoặc không còn kịp, chọn giờ khác nhé.'),
      );
    }
    final result = await cart.setPickup(uid, slot);
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'pickupTime.confirm');
    return result;
  }

  @override
  void dispose() {
    unawaited(_cartSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_slotSub?.cancel());
    confirm.dispose();
    super.dispose();
  }
}
