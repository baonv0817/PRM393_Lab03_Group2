import 'dart:async';

import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// A03: the pickup windows (S25) of a kiosk. An admin sees the ones to come with how full they are, and makes
/// the next days at once: how many days, which breaks, how long a window lasts, how many orders it takes.
/// Without this the pickup times run out and S25 is empty. A window that exists is never touched.
class AdminSlotsViewModel extends ChangeNotifier with SafeChangeNotifier {
  AdminSlotsViewModel({required this.menu, required this.slots, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    create = Command0(_create);
    load();
  }

  static const noKioskMessage = 'Chưa có kiosk nào. Thêm kiosk trước khi tạo khung giờ.';
  static const emptyMessage = 'Kiosk này chưa có khung giờ nào sắp tới. Tạo ở bên cạnh.';

  final MenuRepository menu;
  final AdminSlotRepository slots;
  final DateTime Function() _clock;

  late final Command0<SlotCreation> create;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  StreamSubscription<List<PickupSlot>>? _slotSub;
  List<Kiosk> _kiosks = const [];
  bool _kiosksLoaded = false;
  String? _kioskId;
  ViewState<List<PickupSlot>> _state = const ViewLoading();
  String _days = '${SlotPlan.defaultDays}';
  String _slotMinutes = '${SlotPlan.defaultSlotMinutes}';
  String _capacity = '${SlotPlan.defaultCapacity}';
  List<String> _breaks = [...SlotPlan.defaultBreakStarts];

  DateTime get now => _clock();
  List<Kiosk> get kiosks => _kiosks;
  bool get kiosksLoaded => _kiosksLoaded;
  String? get kioskId => _kioskId;
  ViewState<List<PickupSlot>> get state => _state;
  String get days => _days;
  String get slotMinutes => _slotMinutes;
  String get capacity => _capacity;
  List<String> get breakStarts => List.unmodifiable(_breaks);

  void load() {
    unawaited(_kioskSub?.cancel());
    _kioskSub = menu.watchKiosks().listen(
      (list) {
        _kiosks = list;
        _kiosksLoaded = true;
        if (_kioskId == null || !list.any((k) => k.id == _kioskId)) {
          _selectInternal(list.firstOrNull?.id);
        }
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        _kiosksLoaded = true;
        _state = ViewError(error is AppException ? error.message : 'Không tải được danh sách kiosk.');
        notifyListeners();
      },
    );
  }

  void selectKiosk(String id) {
    if (id == _kioskId) return;
    _selectInternal(id);
    notifyListeners();
  }

  void _selectInternal(String? id) {
    unawaited(_slotSub?.cancel());
    _kioskId = id;
    if (id == null) {
      _state = const ViewEmpty(noKioskMessage);
      return;
    }
    _state = const ViewLoading();
    _slotSub = slots
        .watchSlots(id, from: now)
        .listen(
          (list) {
            _state = list.isEmpty ? const ViewEmpty(emptyMessage) : ViewData(list);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            _state = ViewError(error is AppException ? error.message : 'Không tải được khung giờ.');
            notifyListeners();
          },
        );
  }

  void setDays(String value) => _set(() => _days = value);

  void setSlotMinutes(String value) => _set(() => _slotMinutes = value);

  void setCapacity(String value) => _set(() => _capacity = value);

  /// Adds a break start ("08:45"), keeping the list in order; a time already there is ignored.
  void addBreak(String time) {
    final value = time.trim();
    if (_breaks.contains(value)) return;
    _set(() => _breaks = [..._breaks, value]..sort());
  }

  void removeBreak(String time) => _set(() => _breaks = _breaks.where((t) => t != time).toList());

  void resetBreaks() => _set(() => _breaks = [...SlotPlan.defaultBreakStarts]);

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  /// The plan the form describes; a number that is not a number gives a value no plan accepts, so [problem] says so.
  SlotPlan get plan => SlotPlan(
    kioskId: _kioskId ?? '',
    days: int.tryParse(_days.trim()) ?? 0,
    breakStarts: _breaks,
    slotMinutes: int.tryParse(_slotMinutes.trim()) ?? 0,
    capacity: int.tryParse(_capacity.trim()) ?? 0,
  );

  String? get problem => plan.problem;

  /// How many windows the plan would make from now, counting the ones that already exist.
  int get planned => plan.slots(from: now).length;

  Future<Result<SlotCreation>> _create() async {
    final problem = this.problem;
    if (problem != null) return Result.error(ValidationException(problem));
    return slots.createSlots(plan, from: now);
  }

  @override
  void dispose() {
    unawaited(_kioskSub?.cancel());
    unawaited(_slotSub?.cancel());
    create.dispose();
    super.dispose();
  }
}
