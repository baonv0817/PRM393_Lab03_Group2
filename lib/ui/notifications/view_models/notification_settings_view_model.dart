import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// The four switches of S18. There is no save button: a switch is written as soon as it is flipped, and goes
/// back by itself when the write fails.
enum NotificationSwitch {
  orderReady('Món sẵn sàng', 'Báo khi đơn sẵn sàng để nhận'),
  breakReminder('Nhắc trước giờ nghỉ', 'Nhắc đặt món trước giờ nghỉ 10 phút'),
  promo('Khuyến mãi', 'Ưu đãi theo giờ vàng'),
  orderUpdates('Cập nhật đơn', 'Khi trạng thái đơn thay đổi');

  const NotificationSwitch(this.title, this.subtitle);

  final String title;
  final String subtitle;

  bool valueIn(NotificationPrefs prefs) => switch (this) {
    orderReady => prefs.orderReady,
    breakReminder => prefs.breakReminder,
    promo => prefs.promo,
    orderUpdates => prefs.orderUpdates,
  };

  NotificationPrefs set(NotificationPrefs prefs, bool value) => switch (this) {
    orderReady => prefs.copyWith(orderReady: value),
    breakReminder => prefs.copyWith(breakReminder: value),
    promo => prefs.copyWith(promo: value),
    orderUpdates => prefs.copyWith(orderUpdates: value),
  };
}

class NotificationSettingsViewModel extends ChangeNotifier with SafeChangeNotifier {
  NotificationSettingsViewModel({required this.notifications, required this.crash, required this.uid}) {
    load();
  }

  final NotificationRepository notifications;
  final CrashService crash;
  final String uid;

  StreamSubscription<NotificationPrefs>? _sub;
  ViewState<NotificationPrefs> _state = const ViewLoading();
  NotificationPrefs? _pending;

  ViewState<NotificationPrefs> get state => _state;

  /// What the switches show: the value being written, if there is one, else the stored one.
  NotificationPrefs? get prefs => _pending ?? _state.dataOrNull;

  bool get saving => _pending != null;

  bool valueOf(NotificationSwitch option) => option.valueIn(prefs ?? NotificationPrefs.defaults);

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _sub = notifications
        .watchPrefs(uid)
        .listen(
          (prefs) {
            _state = ViewData(prefs);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'notificationSettings.watch');
            _state = ViewError(error is AppException ? error.message : 'Không tải được cài đặt thông báo.');
            notifyListeners();
          },
        );
  }

  /// Flips [option] to [value]. The switch moves at once; when the write fails it moves back and the error is
  /// returned so the screen can say why.
  Future<Result<void>> set(NotificationSwitch option, bool value) async {
    final current = prefs;
    if (current == null || saving || option.valueIn(current) == value) return const Result.ok(null);
    _pending = option.set(current, value);
    notifyListeners();
    try {
      final result = await notifications.setPrefs(uid, _pending!);
      if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'notificationSettings.set');
      return result;
    } finally {
      _pending = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
