import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

/// Kiosks as an admin manages them (A02): everything about a kiosk, not only what its staff may change (K10).
abstract interface class AdminKioskRepository {
  /// Saves [kiosk]. A new one (`isNew`) must have a free id; an existing one keeps its id and its pause. Empty
  /// fields (no hours, no notice) are removed. The change and its audit line are written together. Fails with
  /// `ValidationException` for a wrong value or an id already taken, `NotFoundException` for an unknown kiosk.
  Future<Result<void>> save(Kiosk kiosk, {required bool isNew});
}
