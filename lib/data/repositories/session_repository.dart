import 'package:breakbite/utils/result.dart';

/// Client-side state shared by several screens: the kiosk the customer orders from (S02, S03, S05,
/// S27). A repository, not a view model, so every view model reads the same source of truth.
abstract interface class SessionRepository {
  /// Emits the current kiosk id first (`null` until one is chosen), then every change.
  Stream<String?> watchSelectedKioskId();

  String? get selectedKioskId;

  /// Picks the kiosk (S27, or Home choosing the first open kiosk). The cart belongs to one kiosk,
  /// so the caller asks the customer before switching away from a non-empty cart.
  Future<Result<void>> selectKiosk(String kioskId);

  /// Forgets everything on sign-out.
  Future<Result<void>> clear();
}
