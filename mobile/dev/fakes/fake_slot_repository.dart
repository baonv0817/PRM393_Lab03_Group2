import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/domain/models/models.dart';

import 'live_value.dart';

class FakeSlotRepository implements SlotRepository {
  FakeSlotRepository({Map<String, List<PickupSlot>>? slots, DateTime Function()? clock})
    : _slots = LiveValue(slots ?? _threeDaysOfSlots((clock ?? DateTime.now)()));

  static const breaks = [(8, 45), (10, 15), (13, 15), (14, 45)];
  static const openKiosks = ['q9-t2', 'q9-t4'];

  final LiveValue<Map<String, List<PickupSlot>>> _slots;

  static Map<String, List<PickupSlot>> _threeDaysOfSlots(DateTime now) => {
    for (final kiosk in openKiosks)
      kiosk: [
        for (var day = 0; day < 3; day++)
          for (final (hour, minute) in breaks)
            slotAt(DateTime(now.year, now.month, now.day + day, hour, minute), full: day == 0 && hour == 13),
      ],
  };

  static PickupSlot slotAt(DateTime startAt, {bool full = false}) {
    String two(int value) => value.toString().padLeft(2, '0');
    return PickupSlot(
      id: '${startAt.year}${two(startAt.month)}${two(startAt.day)}-${two(startAt.hour)}${two(startAt.minute)}',
      startAt: startAt,
      endAt: startAt.add(const Duration(minutes: 15)),
      capacity: 15,
      booked: full ? 15 : 0,
    );
  }

  @override
  Stream<List<PickupSlot>> watchUpcomingSlots(String kioskId, {required DateTime from}) => _slots.stream.map(
    (all) =>
        (all[kioskId] ?? const <PickupSlot>[]).where((s) => !s.startAt.isBefore(from)).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt)),
  );
}
