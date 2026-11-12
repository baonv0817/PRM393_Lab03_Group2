import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SlotPlan', () {
    // Wednesday 11 November 2026, 07:00 in Vietnam.
    final morning = DateTime.utc(2026, 11, 10, 24);

    test('makes the breaks of each working day, on the Vietnam clock, with ids made of the date and the time', () {
      const plan = SlotPlan(kioskId: 'q9-t2', days: 1, breakStarts: ['10:15', '08:45']);
      final slots = plan.slots(from: morning);

      expect(slots.map((s) => s.id), ['20261111-0845', '20261111-1015'], reason: 'earliest first');
      expect(slots.first.startAt, DateTime.utc(2026, 11, 11, 1, 45), reason: '08:45 in Vietnam is 01:45 UTC');
      expect(slots.first.endAt.difference(slots.first.startAt), const Duration(minutes: 15));
      expect((slots.first.capacity, slots.first.booked), (15, 0));
    });

    test('skips Saturdays and Sundays and counts calendar days from today', () {
      const plan = SlotPlan(kioskId: 'k', days: 7, breakStarts: ['10:15']);
      final days = plan.slots(from: morning).map((s) => s.id.substring(0, 8)).toList();
      // Wed 11, Thu 12, Fri 13, (Sat 14, Sun 15), Mon 16, Tue 17.
      expect(days, ['20261111', '20261112', '20261113', '20261116', '20261117']);
    });

    test('leaves out the windows of today that have already started', () {
      const plan = SlotPlan(kioskId: 'k', days: 1, breakStarts: ['08:45', '10:15', '13:15']);
      final tenOClock = DateTime.utc(2026, 11, 11, 3); // 10:00 in Vietnam
      expect(plan.slots(from: tenOClock).map((s) => s.id), ['20261111-1015', '20261111-1315']);
      expect(plan.slots(from: DateTime.utc(2026, 11, 11, 3, 15)).map((s) => s.id), ['20261111-1315']);
    });

    test('uses the Vietnam date, not the computer date: late in the evening UTC is already tomorrow there', () {
      const plan = SlotPlan(kioskId: 'k', days: 1, breakStarts: ['08:45']);
      final lateUtc = DateTime.utc(2026, 11, 11, 20); // 03:00 on 12 November in Vietnam
      expect(plan.slots(from: lateUtc).single.id, '20261112-0845');
    });

    test('the same plan gives the same ids, so a day made twice is not made twice', () {
      const plan = SlotPlan(kioskId: 'k', days: 3);
      expect(plan.slots(from: morning).map((s) => s.id), plan.slots(from: morning).map((s) => s.id));
    });

    test('says what is wrong with a plan, and makes nothing from it', () {
      expect(const SlotPlan(kioskId: '').problem, 'Chọn kiosk.');
      expect(const SlotPlan(kioskId: 'k', days: 0).problem, contains('Số ngày'));
      expect(const SlotPlan(kioskId: 'k', days: 31).problem, contains('Số ngày'));
      expect(const SlotPlan(kioskId: 'k', breakStarts: []).problem, contains('ít nhất một'));
      expect(const SlotPlan(kioskId: 'k', breakStarts: ['8:45']).problem, contains('08:45'));
      expect(const SlotPlan(kioskId: 'k', breakStarts: ['08:45', '08:45']).problem, contains('trùng'));
      expect(const SlotPlan(kioskId: 'k', slotMinutes: 4).problem, contains('Mỗi khung'));
      expect(const SlotPlan(kioskId: 'k', capacity: 0).problem, contains('Sức chứa'));
      expect(const SlotPlan(kioskId: 'k').problem, isNull);

      const bad = SlotPlan(kioskId: 'k', capacity: 0);
      expect(bad.slots(from: morning), isEmpty);
    });
  });
}
