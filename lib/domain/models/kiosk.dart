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
  });

  final String id;
  final String name;
  final bool open;
  final int waitMinutes;

  /// Full location, e.g. "Campus Q9, tầng 2".
  final String location;

  /// Opening and closing times in "HH:mm" format.
  final String? openTime;
  final String? closeTime;

  /// Notice shown on the Home screen when the kiosk is closed or something changes (S21).
  final String? notice;
}
