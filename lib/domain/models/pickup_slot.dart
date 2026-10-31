/// Một khung giờ nhận món của kiosk, ứng với giờ ra chơi giữa hai slot (S25).
class PickupSlot {
  const PickupSlot({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.booked,
  });

  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final int capacity;
  final int booked;

  int get remaining => capacity - booked;
  bool get isFull => booked >= capacity;
}
