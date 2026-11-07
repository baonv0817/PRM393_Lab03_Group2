/// The four switches of S18. Order updates are on by default, promotions off (as in Figma).
class NotificationPrefs {
  const NotificationPrefs({
    this.orderReady = true,
    this.breakReminder = true,
    this.promo = false,
    this.orderUpdates = true,
  });

  static const defaults = NotificationPrefs();

  /// "Món sẵn sàng": a note when the order is ready to collect.
  final bool orderReady;

  /// "Nhắc trước giờ nghỉ": a reminder before the break the customer entered (S25).
  final bool breakReminder;

  /// "Khuyến mãi": offers from the kiosk.
  final bool promo;

  /// "Cập nhật đơn": a note when the state of an order changes (accepted, cancelled, handed over).
  final bool orderUpdates;

  NotificationPrefs copyWith({bool? orderReady, bool? breakReminder, bool? promo, bool? orderUpdates}) =>
      NotificationPrefs(
        orderReady: orderReady ?? this.orderReady,
        breakReminder: breakReminder ?? this.breakReminder,
        promo: promo ?? this.promo,
        orderUpdates: orderUpdates ?? this.orderUpdates,
      );

  /// How it is stored in `users/{uid}.notificationPrefs`.
  Map<String, bool> toMap() => {
    'orderReady': orderReady,
    'breakReminder': breakReminder,
    'promo': promo,
    'orderUpdates': orderUpdates,
  };

  /// Reads the stored map; a missing key keeps its default, so a profile saved before S18 still works.
  factory NotificationPrefs.fromMap(Object? data) {
    if (data is! Map) return defaults;
    bool read(String key, bool fallback) => data[key] is bool ? data[key] as bool : fallback;
    return NotificationPrefs(
      orderReady: read('orderReady', defaults.orderReady),
      breakReminder: read('breakReminder', defaults.breakReminder),
      promo: read('promo', defaults.promo),
      orderUpdates: read('orderUpdates', defaults.orderUpdates),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.orderReady == orderReady &&
      other.breakReminder == breakReminder &&
      other.promo == promo &&
      other.orderUpdates == orderUpdates;

  @override
  int get hashCode => Object.hash(orderReady, breakReminder, promo, orderUpdates);
}
