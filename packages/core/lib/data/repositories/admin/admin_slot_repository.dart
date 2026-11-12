import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

/// What making slots did: how many windows were new, and how many already existed (left as they were, with their
/// bookings).
class SlotCreation {
  const SlotCreation({required this.created, required this.existing});

  final int created;
  final int existing;
}

/// The pickup windows of a kiosk as an admin manages them (A03).
abstract interface class AdminSlotRepository {
  /// The windows of [kioskId] that start at or after [from], earliest first, live.
  Stream<List<PickupSlot>> watchSlots(String kioskId, {required DateTime from});

  /// Creates the windows of [plan] that do not exist yet, with no booking. A window that exists is never
  /// overwritten, so the orders already booked in it stay counted. Fails with `ValidationException` for a plan
  /// that has a problem.
  Future<Result<SlotCreation>> createSlots(SlotPlan plan, {required DateTime from});
}
