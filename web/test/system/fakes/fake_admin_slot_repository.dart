import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

import '../live_value.dart';
import 'fake_audit_log.dart';

class FakeAdminSlotRepository implements AdminSlotRepository {
  FakeAdminSlotRepository(this.audit, {this.kioskIds = const {'q9-t2', 'q9-t4', 'nvh-t1'}});

  final FakeAuditLog audit;
  final Set<String> kioskIds;
  final _slots = <String, LiveValue<List<PickupSlot>>>{};
  AppException? failNext;

  LiveValue<List<PickupSlot>> _of(String kioskId) => _slots.putIfAbsent(kioskId, () => LiveValue(const []));

  List<PickupSlot> slotsOf(String kioskId) => _of(kioskId).value;

  /// Puts a slot in, as if it already existed (with bookings, for example).
  void seed(String kioskId, PickupSlot slot) =>
      _of(kioskId).set([...slotsOf(kioskId).where((s) => s.id != slot.id), slot]..sort(_byStart));

  static int _byStart(PickupSlot a, PickupSlot b) => a.startAt.compareTo(b.startAt);

  @override
  Stream<List<PickupSlot>> watchSlots(String kioskId, {required DateTime from}) => _of(kioskId).stream.map(
    (list) => [
      for (final s in list)
        if (!s.startAt.isBefore(from)) s,
    ],
  );

  @override
  Future<Result<SlotCreation>> createSlots(SlotPlan plan, {required DateTime from}) async {
    if (failNext case final error?) {
      failNext = null;
      return Result.error(error);
    }
    final problem = plan.problem;
    if (problem != null) return Result.error(ValidationException(problem));
    if (!kioskIds.contains(plan.kioskId)) {
      return const Result.error(NotFoundException(message: 'Không tìm thấy kiosk này.'));
    }
    final wanted = plan.slots(from: from);
    if (wanted.isEmpty) {
      return const Result.error(ValidationException('Không có khung giờ nào sắp tới trong các ngày đã chọn.'));
    }
    final have = slotsOf(plan.kioskId).map((s) => s.id).toSet();
    final fresh = [
      for (final s in wanted)
        if (!have.contains(s.id)) s,
    ];
    if (fresh.isNotEmpty) {
      _of(plan.kioskId).set([...slotsOf(plan.kioskId), ...fresh]..sort(_byStart));
      audit.record(
        AuditAction.slotsCreate,
        'kiosks/${plan.kioskId}/slots',
        'Tạo ${fresh.length} khung giờ cho kiosk ${plan.kioskId} (${plan.days} ngày, sức chứa ${plan.capacity})',
      );
    }
    return Result.ok(SlotCreation(created: fresh.length, existing: wanted.length - fresh.length));
  }
}
