const _keep = Object();

/// What staff set in K10: the fields of a kiosk that the rules let them change. It is written as a whole,
/// so an empty field (no pause, no notice) is removed from the kiosk.
class KioskSettings {
  const KioskSettings({
    required this.open,
    required this.waitMinutes,
    this.pausedUntil,
    this.maxOrdersPerSlot,
    this.notice,
    this.openTime,
    this.closeTime,
  });

  /// The settings a kiosk has now.
  factory KioskSettings.of(Kiosk kiosk) => KioskSettings(
    open: kiosk.open,
    waitMinutes: kiosk.waitMinutes,
    pausedUntil: kiosk.pausedUntil,
    maxOrdersPerSlot: kiosk.maxOrdersPerSlot,
    notice: kiosk.notice,
    openTime: kiosk.openTime,
    closeTime: kiosk.closeTime,
  );

  static const maxWaitMinutes = 120;
  static const maxNoticeLength = 120;
  static final _clock = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// "06:30" and "17:00" are valid, "6:30" and "25:00" are not.
  static bool isClockTime(String value) => _clock.hasMatch(value);

  /// Why these settings cannot be saved, or `null`; the repositories and the screen share it.
  String? get problem {
    if (waitMinutes < 0 || waitMinutes > maxWaitMinutes) return 'Thời gian chờ từ 0 đến $maxWaitMinutes phút.';
    if (maxOrdersPerSlot != null && maxOrdersPerSlot! <= 0) return 'Số đơn tối đa mỗi khung giờ phải lớn hơn 0.';
    if ((notice?.length ?? 0) > maxNoticeLength) return 'Thông báo tối đa $maxNoticeLength ký tự.';
    for (final time in [openTime, closeTime]) {
      if (time != null && !isClockTime(time)) return 'Giờ phải có dạng 06:30.';
    }
    return null;
  }

  /// "Đang nhận đơn": when false customers cannot order.
  final bool open;

  /// Estimated wait, 0 to [maxWaitMinutes].
  final int waitMinutes;

  /// No orders until this time (K10 "tạm ngưng").
  final DateTime? pausedUntil;

  /// Default capacity of new pickup slots; more than 0 when set.
  final int? maxOrdersPerSlot;
  final String? notice;

  /// "HH:mm": the opening hours. Orders are refused outside them (`isWithinHours`); both times are needed.
  final String? openTime;
  final String? closeTime;

  /// A copy with some fields changed; pass `null` to a nullable field to clear it.
  KioskSettings copyWith({
    bool? open,
    int? waitMinutes,
    Object? pausedUntil = _keep,
    Object? maxOrdersPerSlot = _keep,
    Object? notice = _keep,
    Object? openTime = _keep,
    Object? closeTime = _keep,
  }) => KioskSettings(
    open: open ?? this.open,
    waitMinutes: waitMinutes ?? this.waitMinutes,
    pausedUntil: identical(pausedUntil, _keep) ? this.pausedUntil : pausedUntil as DateTime?,
    maxOrdersPerSlot: identical(maxOrdersPerSlot, _keep) ? this.maxOrdersPerSlot : maxOrdersPerSlot as int?,
    notice: identical(notice, _keep) ? this.notice : notice as String?,
    openTime: identical(openTime, _keep) ? this.openTime : openTime as String?,
    closeTime: identical(closeTime, _keep) ? this.closeTime : closeTime as String?,
  );
}

class Kiosk {
  const Kiosk({
    required this.id,
    required this.name,
    required this.open,
    required this.waitMinutes,
    this.location = '',
    this.openTime,
    this.closeTime,
    this.notice,
    this.pausedUntil,
    this.maxOrdersPerSlot,
  });

  final String id;
  final String name;
  final bool open;
  final int waitMinutes;
  final String location;
  final String? openTime;
  final String? closeTime;
  final String? notice;
  final DateTime? pausedUntil;
  final int? maxOrdersPerSlot;

  /// Minutes after midnight of "HH:mm", or `null` when it is not set or not a clock time.
  static int? _minutesOf(String? time) {
    if (time == null || !KioskSettings.isClockTime(time)) return null;
    return int.parse(time.substring(0, 2)) * 60 + int.parse(time.substring(3));
  }

  /// Within the opening hours of K10, read on the clock of [now] (the phone's, which is Vietnam time for the
  /// students and staff using it). Without both times, or with the same time twice, the kiosk has no hours and
  /// this is always true. Closing before opening means the hours run past midnight.
  bool isWithinHours(DateTime now) {
    final from = _minutesOf(openTime);
    final to = _minutesOf(closeTime);
    if (from == null || to == null || from == to) return true;
    final minute = now.hour * 60 + now.minute;
    return from < to ? minute >= from && minute < to : minute >= from || minute < to;
  }

  /// A pause ("tạm ngưng", K10) is running at [now].
  bool isPaused(DateTime now) => pausedUntil != null && pausedUntil!.isAfter(now);

  /// Whether an order can be placed at [now]: the "Đang nhận đơn" switch is on, it is within the opening hours
  /// and no pause is running.
  bool acceptsOrders(DateTime now) => open && isWithinHours(now) && !isPaused(now);
}
