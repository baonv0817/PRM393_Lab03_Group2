import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

/// Discount codes as an admin manages them (A04). Customers only read them (`VoucherRepository`).
abstract interface class AdminVoucherRepository {
  /// Every voucher, live: active, switched off and expired ones.
  Stream<List<Voucher>> watchAll();

  /// Saves [voucher]. A new one (`isNew`) must have a free code; an existing one keeps its code. A start time or
  /// active hours that are empty are removed. The change and its audit line are written together. Fails with
  /// `ValidationException` for a wrong value or a code that is taken, `NotFoundException` for an unknown code.
  Future<Result<void>> save(Voucher voucher, {required bool isNew});

  /// Switches a voucher on or off without touching the rest. Fails with `NotFoundException` for an unknown code.
  Future<Result<void>> setActive(String code, bool active);
}
