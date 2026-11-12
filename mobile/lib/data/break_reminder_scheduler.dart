import 'dart:async';

import 'package:breakbite_core/data/repositories/notification_repository.dart';
import 'package:breakbite_core/data/repositories/session_repository.dart';
import 'package:breakbite_core/data/repositories/slot_repository.dart';
import 'package:breakbite_core/data/services/crash_service.dart';
import 'package:breakbite_core/data/services/reminder_service.dart';
import 'package:breakbite_core/domain/models/models.dart';

/// D33, "Nhắc trước giờ nghỉ" of S18: while a customer is signed in and the switch is on, the phone reminds
/// them [lead] before each break of the selected kiosk in the next [horizon], so they can order ahead.
/// The breaks are the kiosk's pickup slots (S25). Turning the switch off, changing kiosk or signing out
/// replaces or removes the reminders.
class BreakReminderScheduler {
  BreakReminderScheduler({
    required this.notifications,
    required this.session,
    required this.slots,
    required this.reminders,
    required this.crash,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const lead = Duration(minutes: 10);
  static const horizon = Duration(hours: 24);
  static const maxReminders = 8;

  final NotificationRepository notifications;
  final SessionRepository session;
  final SlotRepository slots;
  final ReminderService reminders;
  final CrashService crash;
  final DateTime Function() _clock;

  StreamSubscription<NotificationPrefs>? _prefsSub;
  StreamSubscription<String?>? _kioskSub;
  StreamSubscription<List<PickupSlot>>? _slotsSub;
  bool _enabled = NotificationPrefs.defaults.breakReminder;
  List<PickupSlot> _slots = const [];
  List<BreakReminder>? _applied;

  /// The reminders for [upcoming] breaks at [now]: [lead] before each distinct break start that is still
  /// ahead, within [horizon], at most [maxReminders], earliest first.
  static List<BreakReminder> remindersFor(List<PickupSlot> upcoming, DateTime now) {
    final starts = upcoming.map((s) => s.startAt).toSet().toList()..sort();
    return [
      for (final start in starts)
        if (start.subtract(lead).isAfter(now) && start.isBefore(now.add(horizon)))
          BreakReminder(at: start.subtract(lead), breakStart: start),
    ].take(maxReminders).toList();
  }

  void start(String uid) {
    stop();
    _prefsSub = notifications.watchPrefs(uid).listen((prefs) {
      _enabled = prefs.breakReminder;
      _apply();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'breakReminder.watchPrefs'));
    _kioskSub = session.watchSelectedKioskId().listen(
      _watchKiosk,
      onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'breakReminder.watchKiosk'),
    );
  }

  void _watchKiosk(String? kioskId) {
    unawaited(_slotsSub?.cancel());
    _slotsSub = null;
    _slots = const [];
    if (kioskId == null || kioskId.isEmpty) {
      _apply();
      return;
    }
    _slotsSub = slots.watchUpcomingSlots(kioskId, from: _clock()).listen((list) {
      _slots = list;
      _apply();
    }, onError: (Object e, StackTrace s) => crash.recordNonFatal(e, s, 'breakReminder.watchSlots'));
  }

  void _apply() {
    final next = _enabled ? remindersFor(_slots, _clock()) : const <BreakReminder>[];
    final before = _applied;
    if (before != null && _same(before, next)) return;
    _applied = next;
    unawaited(next.isEmpty ? reminders.cancelBreakReminders() : reminders.scheduleBreakReminders(next));
  }

  static bool _same(List<BreakReminder> a, List<BreakReminder> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Stops watching and removes the reminders (sign-out, or a staff account).
  void stop() {
    final wasRunning = _prefsSub != null;
    unawaited(_prefsSub?.cancel());
    unawaited(_kioskSub?.cancel());
    unawaited(_slotsSub?.cancel());
    _prefsSub = null;
    _kioskSub = null;
    _slotsSub = null;
    _slots = const [];
    _enabled = NotificationPrefs.defaults.breakReminder;
    if (wasRunning && (_applied?.isNotEmpty ?? false)) unawaited(reminders.cancelBreakReminders());
    _applied = null;
  }
}
