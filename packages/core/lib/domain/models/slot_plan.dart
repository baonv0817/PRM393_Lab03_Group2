import 'package:breakbite_core/domain/models/kiosk.dart';
import 'package:breakbite_core/domain/models/pickup_slot.dart';

/// What the admin chooses to create the pickup times (S25) of a kiosk for the days to come: how many days, the
/// breaks, how long a window lasts and how many orders it takes. Saturdays and Sundays are skipped.
class SlotPlan {
  const SlotPlan({
    required this.kioskId,
    this.days = defaultDays,
    this.breakStarts = defaultBreakStarts,
    this.slotMinutes = defaultSlotMinutes,
    this.capacity = defaultCapacity,
  });

  /// The same values the seed uses.
  static const defaultBreakStarts = ['08:45', '10:15', '13:15', '14:45'];
  static const defaultDays = 14;
  static const defaultSlotMinutes = 15;
  static const defaultCapacity = 15;
  static const maxDays = 30;
  static const maxBreaks = 8;
  static const maxSlotMinutes = 60;
  static const maxCapacity = 200;

  /// Vietnam is seven hours ahead of UTC all year; the slots are on that clock whatever the computer's.
  static const vietnamOffset = Duration(hours: 7);

  final String kioskId;

  /// Calendar days counted from today, today included.
  final int days;
  final List<String> breakStarts;
  final int slotMinutes;
  final int capacity;

  /// Why this plan cannot be made, or `null`.
  String? get problem {
    if (kioskId.isEmpty) return 'Chọn kiosk.';
    if (days < 1 || days > maxDays) return 'Số ngày từ 1 đến $maxDays.';
    if (breakStarts.isEmpty) return 'Thêm ít nhất một giờ ra chơi.';
    if (breakStarts.length > maxBreaks) return 'Tối đa $maxBreaks giờ ra chơi mỗi ngày.';
    for (final time in breakStarts) {
      if (!KioskSettings.isClockTime(time)) return 'Giờ phải có dạng 08:45.';
    }
    if (breakStarts.toSet().length != breakStarts.length) return 'Có giờ ra chơi bị trùng.';
    if (slotMinutes < 5 || slotMinutes > maxSlotMinutes) return 'Mỗi khung dài từ 5 đến $maxSlotMinutes phút.';
    if (capacity < 1 || capacity > maxCapacity) return 'Sức chứa từ 1 đến $maxCapacity đơn.';
    return null;
  }

  /// The windows of the plan that start after [from], earliest first. The id is `yyyyMMdd-HHmm` on the Vietnam
  /// clock, so making the same day twice gives the same ids and nothing is created twice.
  List<PickupSlot> slots({required DateTime from}) {
    if (problem != null) return const [];
    final vietnam = from.toUtc().add(vietnamOffset);
    final result = <PickupSlot>[];
    for (var i = 0; i < days; i++) {
      final day = DateTime.utc(vietnam.year, vietnam.month, vietnam.day + i);
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) continue;
      final sorted = [...breakStarts]..sort();
      for (final time in sorted) {
        final hour = int.parse(time.substring(0, 2));
        final minute = int.parse(time.substring(3));
        final start = DateTime.utc(day.year, day.month, day.day, hour, minute).subtract(vietnamOffset);
        if (!start.isAfter(from.toUtc())) continue;
        result.add(
          PickupSlot(
            id: '${_two(day.year, 4)}${_two(day.month)}${_two(day.day)}-${_two(hour)}${_two(minute)}',
            startAt: start,
            endAt: start.add(Duration(minutes: slotMinutes)),
            capacity: capacity,
            booked: 0,
          ),
        );
      }
    }
    return result;
  }

  static String _two(int value, [int width = 2]) => value.toString().padLeft(width, '0');
}
