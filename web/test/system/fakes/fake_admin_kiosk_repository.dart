import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

import '../fake_menu_repository.dart';
import 'fake_audit_log.dart';

/// Works on the kiosks of the fake menu repository, so the lists of the website follow what is saved.
class FakeAdminKioskRepository implements AdminKioskRepository {
  FakeAdminKioskRepository(this.menu, this.audit);

  static final _id = RegExp(r'^[a-z0-9][a-z0-9-]{1,29}$');

  final FakeMenuRepository menu;
  final FakeAuditLog audit;
  AppException? failNext;

  @override
  Future<Result<void>> save(Kiosk kiosk, {required bool isNew}) async {
    if (failNext case final error?) {
      failNext = null;
      return Result.error(error);
    }
    if (kiosk.name.trim().isEmpty) return const Result.error(ValidationException('Nhập tên kiosk.'));
    final problem = KioskSettings.of(kiosk).problem;
    if (problem != null) return Result.error(ValidationException(problem));
    final index = menu.kiosks.indexWhere((k) => k.id == kiosk.id);
    if (isNew) {
      if (!_id.hasMatch(kiosk.id)) {
        return const Result.error(
          ValidationException('Mã kiosk gồm chữ thường, số và dấu gạch ngang, 2 đến 30 ký tự.'),
        );
      }
      if (index >= 0) return Result.error(ValidationException('Mã kiosk "${kiosk.id}" đã có.'));
    } else if (index < 0) {
      return const Result.error(NotFoundException(message: 'Không tìm thấy kiosk này.'));
    }
    final notice = kiosk.notice?.trim() ?? '';
    final stored = Kiosk(
      id: kiosk.id,
      name: kiosk.name.trim(),
      location: kiosk.location.trim(),
      open: kiosk.open,
      waitMinutes: kiosk.waitMinutes,
      openTime: kiosk.openTime,
      closeTime: kiosk.closeTime,
      notice: notice.isEmpty ? null : notice,
      pausedUntil: isNew ? null : menu.kiosks[index].pausedUntil,
      maxOrdersPerSlot: kiosk.maxOrdersPerSlot,
    );
    if (isNew) {
      menu.kiosks = [...menu.kiosks, stored];
    } else {
      menu.kiosks = [...menu.kiosks]..[index] = stored;
    }
    audit.record(
      AuditAction.kioskSave,
      'kiosks/${kiosk.id}',
      isNew ? 'Thêm kiosk ${stored.name}' : 'Sửa kiosk ${stored.name}',
    );
    return const Result.ok(null);
  }
}
