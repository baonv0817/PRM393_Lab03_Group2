import 'package:breakbite/domain/models/pickup_slot.dart';

abstract interface class SlotRepository {
  static const upcomingLimit = 28;

  Stream<List<PickupSlot>> watchUpcomingSlots(String kioskId, {required DateTime from});
}
