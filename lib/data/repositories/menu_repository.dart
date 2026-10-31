import 'package:breakbite/domain/models/kiosk.dart';
import 'package:breakbite/domain/models/menu_item.dart';
import 'package:breakbite/domain/models/voucher.dart';
import 'package:breakbite/utils/result.dart';

abstract interface class MenuRepository {
  /// Menu of one kiosk: every item belongs to exactly one kiosk (`MenuItem.kioskId`).
  Stream<List<MenuItem>> watchMenu(String kioskId);

  /// Fails with `NotFoundException` when the item does not exist.
  Future<Result<MenuItem>> getItem(String id);

  Stream<List<Kiosk>> watchKiosks();

  /// Fails with `NotFoundException` for an unknown code.
  Future<Result<Voucher>> getVoucher(String code);

  /// Seller only.
  Future<Result<void>> upsertItem(MenuItem item);

  /// Seller only.
  Future<Result<void>> setSoldOut(String id, bool soldOut);
}
