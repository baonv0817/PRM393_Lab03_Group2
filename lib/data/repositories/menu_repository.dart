import 'package:breakbite/domain/models/kiosk.dart';
import 'package:breakbite/domain/models/menu_item.dart';
import 'package:breakbite/domain/models/voucher.dart';
import 'package:breakbite/utils/result.dart';

abstract interface class MenuRepository {
  Stream<List<MenuItem>> watchMenu(String kioskId);

  Future<Result<MenuItem>> getItem(String id);

  Future<Result<Map<String, MenuItem>>> getItems(Iterable<String> ids);

  Stream<List<Kiosk>> watchKiosks();

  Future<Result<Voucher>> getVoucher(String code);

  Future<Result<String>> upsertItem(MenuItem item);

  /// Staff change their kiosk's settings (K10): whether it takes orders, a pause, the wait, the hours, the
  /// notice and the slot capacity. The settings are written as a whole, and an empty one is removed from the
  /// kiosk. Fails with `ValidationException` when [KioskSettings.problem] says so, or `PermissionDenied`
  /// when the account is not staff of that kiosk.
  Future<Result<void>> updateKiosk(String id, KioskSettings settings);

  /// Staff set an item sold out (K09) or available again. [reason] and [availableAgainAt] describe a sold-out
  /// item (the expected time is shown to customers) and are dropped when the item is available again.
  Future<Result<void>> setSoldOut(String id, bool soldOut, {SoldOutReason? reason, DateTime? availableAgainAt});
}
