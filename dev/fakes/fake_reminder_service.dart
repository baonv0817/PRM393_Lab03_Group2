import 'package:breakbite/data/services/services.dart';

class FakeReminderService implements ReminderService {
  /// The reminders scheduled now.
  List<BreakReminder> scheduled = const [];
  int cancels = 0;

  @override
  Future<void> scheduleBreakReminders(List<BreakReminder> reminders) async => scheduled = List.unmodifiable(reminders);

  @override
  Future<void> cancelBreakReminders() async {
    cancels++;
    scheduled = const [];
  }
}
