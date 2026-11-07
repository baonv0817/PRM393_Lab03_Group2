/// One break reminder (D33): shown at [at], about the break that starts at [breakStart].
class BreakReminder {
  const BreakReminder({required this.at, required this.breakStart});

  final DateTime at;
  final DateTime breakStart;

  @override
  bool operator ==(Object other) => other is BreakReminder && other.at == at && other.breakStart == breakStart;

  @override
  int get hashCode => Object.hash(at, breakStart);
}

/// Notifications the phone shows by itself at a set time, without a server (the app has none, data-model
/// section 6). Never throws: a reminder that cannot be scheduled is simply not shown.
abstract interface class ReminderService {
  /// Replaces every scheduled break reminder with [reminders].
  Future<void> scheduleBreakReminders(List<BreakReminder> reminders);

  /// Removes every scheduled break reminder (switch off, sign-out).
  Future<void> cancelBreakReminders();
}
