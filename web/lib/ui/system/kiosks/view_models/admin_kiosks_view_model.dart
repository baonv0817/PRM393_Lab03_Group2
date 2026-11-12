import 'dart:async';

import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:breakbite_core/utils/text.dart';
import 'package:flutter/foundation.dart';

/// What an admin typed for a kiosk (A02): the text of each field, so a half-typed form can be checked and shown
/// without being a [Kiosk] yet.
class KioskForm {
  const KioskForm({
    this.id = '',
    this.name = '',
    this.location = '',
    this.open = true,
    this.wait = '6',
    this.openTime = '',
    this.closeTime = '',
    this.notice = '',
    this.maxOrders = '',
  });

  factory KioskForm.of(Kiosk kiosk) => KioskForm(
    id: kiosk.id,
    name: kiosk.name,
    location: kiosk.location,
    open: kiosk.open,
    wait: '${kiosk.waitMinutes}',
    openTime: kiosk.openTime ?? '',
    closeTime: kiosk.closeTime ?? '',
    notice: kiosk.notice ?? '',
    maxOrders: kiosk.maxOrdersPerSlot == null ? '' : '${kiosk.maxOrdersPerSlot}',
  );

  final String id;
  final String name;
  final String location;
  final bool open;
  final String wait;
  final String openTime;
  final String closeTime;
  final String notice;
  final String maxOrders;

  /// The kiosk these fields describe, or `null` while a number is not a number.
  Kiosk? toKiosk() {
    final waitMinutes = int.tryParse(wait.trim());
    if (waitMinutes == null) return null;
    final max = maxOrders.trim().isEmpty ? null : int.tryParse(maxOrders.trim());
    if (maxOrders.trim().isNotEmpty && max == null) return null;
    return Kiosk(
      id: id.trim(),
      name: name.trim(),
      location: location.trim(),
      open: open,
      waitMinutes: waitMinutes,
      openTime: openTime.trim().isEmpty ? null : openTime.trim(),
      closeTime: closeTime.trim().isEmpty ? null : closeTime.trim(),
      notice: notice.trim().isEmpty ? null : notice.trim(),
      maxOrdersPerSlot: max,
    );
  }
}

/// A02: the kiosks of the campus. An admin adds a kiosk and edits all of it: name, place, hours, wait, notice,
/// capacity of a pickup window, and whether it takes orders. Its staff change only the daily part (K10).
class AdminKiosksViewModel extends ChangeNotifier with SafeChangeNotifier {
  AdminKiosksViewModel({required this.menu, required this.kiosks}) {
    save = Command1(_save);
    load();
  }

  static const emptyMessage = 'Chưa có kiosk nào. Thêm kiosk đầu tiên.';
  static const maxNameLength = 60;

  final MenuRepository menu;
  final AdminKioskRepository kiosks;

  /// Saves a form; the argument says whether the kiosk is a new one.
  late final Command1<void, ({KioskForm form, bool isNew})> save;
  StreamSubscription<List<Kiosk>>? _sub;
  ViewState<List<Kiosk>> _state = const ViewLoading();

  ViewState<List<Kiosk>> get state => _state;

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _sub = menu.watchKiosks().listen(
      (list) {
        _state = list.isEmpty ? const ViewEmpty(emptyMessage) : ViewData(list);
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        _state = ViewError(error is AppException ? error.message : 'Không tải được danh sách kiosk.');
        notifyListeners();
      },
    );
  }

  /// The id a new kiosk gets from its name: lower case, no accents, dashes.
  static String idFor(String name) => slugify(name);

  /// Why [form] cannot be saved, or `null`.
  String? problemOf(KioskForm form, {required bool isNew}) {
    if (form.name.trim().isEmpty) return 'Nhập tên kiosk.';
    if (form.name.trim().length > maxNameLength) return 'Tên kiosk tối đa $maxNameLength ký tự.';
    if (isNew && !RegExp(r'^[a-z0-9][a-z0-9-]{1,29}$').hasMatch(form.id.trim())) {
      return 'Mã kiosk gồm chữ thường, số và dấu gạch ngang, 2 đến 30 ký tự.';
    }
    final kiosk = form.toKiosk();
    if (kiosk == null) return 'Thời gian chờ và số đơn tối đa phải là số.';
    final hours = [kiosk.openTime, kiosk.closeTime];
    if (hours.where((t) => t == null).length == 1) return 'Nhập đủ giờ mở và giờ đóng, hoặc để trống cả hai.';
    return KioskSettings.of(kiosk).problem;
  }

  Future<Result<void>> _save(({KioskForm form, bool isNew}) change) async {
    final problem = problemOf(change.form, isNew: change.isNew);
    if (problem != null) return Result.error(ValidationException(problem));
    return kiosks.save(change.form.toKiosk()!, isNew: change.isNew);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    save.dispose();
    super.dispose();
  }
}
