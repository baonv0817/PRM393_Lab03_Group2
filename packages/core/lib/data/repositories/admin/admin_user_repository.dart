import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

/// The accounts of the app, for the admin website (A01).
abstract interface class AdminUserRepository {
  /// Most accounts the list holds; the website says so when there are more.
  static const maxUsers = 500;

  /// Every account (at most [maxUsers]), live.
  Stream<List<AppUser>> watchUsers();

  /// Gives [uid] the [role]. A `staff` needs a [kioskId] of a kiosk that exists; any other role has none and
  /// loses the one it had. The change and its line in the audit log are written together. Fails with
  /// `ValidationException` for a staff without a kiosk or with an unknown one, `NotFoundException` for an unknown
  /// account.
  Future<Result<void>> setAccess(String uid, {required UserRole role, String? kioskId});
}
