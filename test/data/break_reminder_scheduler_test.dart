import 'package:breakbite/data/break_reminder_scheduler.dart';
import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fakes/fakes.dart';

final _now = DateTime(2026, 11, 7, 9, 0);

void main() {
  late FakeNotificationRepository notifications;
  late InMemorySessionRepository session;
  late FakeReminderService reminders;

  BreakReminderScheduler build() => BreakReminderScheduler(
    notifications: notifications,
    session: session,
    slots: FakeSlotRepository(clock: () => _now),
    reminders: reminders,
    crash: FakeCrashService(),
    clock: () => _now,
  );

  setUp(() {
    notifications = FakeNotificationRepository();
    session = InMemorySessionRepository(selectedKioskId: 'q9-t2');
    reminders = FakeReminderService();
  });

  test('reminds 10 minutes before each break still ahead in the next 24 hours, earliest first', () {
    final slots = [
      FakeSlotRepository.slotAt(DateTime(2026, 11, 7, 9, 5)), // reminder would be in the past
      FakeSlotRepository.slotAt(DateTime(2026, 11, 7, 10, 15)),
      FakeSlotRepository.slotAt(DateTime(2026, 11, 7, 10, 15)), // same break, one reminder
      FakeSlotRepository.slotAt(DateTime(2026, 11, 7, 13, 15), full: true),
      FakeSlotRepository.slotAt(DateTime(2026, 11, 8, 10, 15)), // more than 24 hours away
    ];
    final list = BreakReminderScheduler.remindersFor(slots, _now);
    expect(list.map((r) => r.at), [DateTime(2026, 11, 7, 10, 5), DateTime(2026, 11, 7, 13, 5)]);
    expect(list.first.breakStart, DateTime(2026, 11, 7, 10, 15));
  });

  test('never schedules more than the limit', () {
    final slots = [for (var i = 0; i < 20; i++) FakeSlotRepository.slotAt(_now.add(Duration(minutes: 30 + 30 * i)))];
    expect(BreakReminderScheduler.remindersFor(slots, _now), hasLength(BreakReminderScheduler.maxReminders));
  });

  test('a signed-in customer with the switch on gets the breaks of the selected kiosk', () async {
    final scheduler = build()..start('u1');
    await pumpEventQueue();
    // Fake slots: 08:45, 10:15, 13:15, 14:45 each day; at 09:00 the next 24 hours hold today's last three
    // and tomorrow's 08:45.
    expect(reminders.scheduled.map((r) => r.breakStart.hour), [10, 13, 14, 8]);
    expect(reminders.scheduled.first.at, DateTime(2026, 11, 7, 10, 5));
    scheduler.stop();
  });

  test('turning the switch off removes the reminders, turning it on brings them back', () async {
    final scheduler = build()..start('u1');
    await pumpEventQueue();
    final cancelsBefore = reminders.cancels;
    await notifications.setPrefs('u1', const NotificationPrefs(breakReminder: false));
    await pumpEventQueue();
    expect(reminders.scheduled, isEmpty);
    expect(reminders.cancels, cancelsBefore + 1);

    await notifications.setPrefs('u1', const NotificationPrefs());
    await pumpEventQueue();
    expect(reminders.scheduled, hasLength(4));
    scheduler.stop();
  });

  test('changing kiosk follows the new kiosk; a kiosk without breaks has no reminders', () async {
    final scheduler = build()..start('u1');
    await pumpEventQueue();
    await session.selectKiosk('nvh-t1');
    await pumpEventQueue();
    expect(reminders.scheduled, isEmpty);
    await session.selectKiosk('q9-t4');
    await pumpEventQueue();
    expect(reminders.scheduled, hasLength(4));
    scheduler.stop();
  });

  test('signing out removes the reminders', () async {
    build()
      ..start('u1')
      ..stop();
    await pumpEventQueue();
    final scheduler = build()..start('u1');
    await pumpEventQueue();
    expect(reminders.scheduled, isNotEmpty);
    scheduler.stop();
    await pumpEventQueue();
    expect(reminders.scheduled, isEmpty);
  });
}
