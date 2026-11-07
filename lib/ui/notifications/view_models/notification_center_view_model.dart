import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// S19: the customer's notifications, "Hôm nay" first and "Trước đó" under it, an unread dot on each new one.
/// Opening a notification marks it read; "Đọc hết" marks them all.
class NotificationCenterViewModel extends ChangeNotifier with SafeChangeNotifier {
  NotificationCenterViewModel({
    required this.notifications,
    required this.crash,
    required this.uid,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    load();
  }

  static const emptyMessage = 'Chưa có thông báo nào. Khi đơn của bạn có tin mới, nó sẽ hiện ở đây.';

  final NotificationRepository notifications;
  final CrashService crash;
  final String uid;
  final DateTime Function() _clock;

  StreamSubscription<List<AppNotification>>? _sub;
  ViewState<List<AppNotification>> _state = const ViewLoading();

  ViewState<List<AppNotification>> get state => _state;

  List<AppNotification> get all => _state.dataOrNull ?? const [];

  int get unreadCount => all.where((n) => !n.read).length;

  /// The notifications of the current day, newest first.
  List<AppNotification> get today => all.where((n) => _isToday(n.receivedAt)).toList();

  /// The older ones, newest first.
  List<AppNotification> get earlier => all.where((n) => !_isToday(n.receivedAt)).toList();

  bool _isToday(DateTime time) {
    final now = _clock();
    final local = time.toLocal();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  /// A notification that says the order is ready; it gets the "Xem mã nhận món" button.
  static bool isReady(AppNotification n) => n.orderId != null && n.id.endsWith('_${OrderStatus.ready.name}');

  void load() {
    unawaited(_sub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _sub = notifications
        .watch(uid)
        .listen(
          (list) {
            _state = ViewStateX.fromList(list, emptyMessage: emptyMessage);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'notifications.watch');
            _state = ViewError(error is AppException ? error.message : 'Không tải được thông báo.');
            notifyListeners();
          },
        );
  }

  /// Marks one notification read. A notification that is already read is left alone (no write).
  Future<Result<void>> open(AppNotification notification) async {
    if (notification.read) return const Result.ok(null);
    final result = await notifications.markRead(uid, notification.id);
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'notifications.markRead');
    return result;
  }

  Future<Result<void>> markAllRead() async {
    if (unreadCount == 0) return const Result.ok(null);
    final result = await notifications.markAllRead(uid);
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'notifications.markAllRead');
    return result;
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
