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

  bool acceptsOrders(DateTime now) => open && (pausedUntil == null || pausedUntil!.isBefore(now));
}
