import '../../domain/models/kiosk.dart';
import '../../domain/models/menu_item.dart';
import '../../domain/models/voucher.dart';

abstract interface class MenuRepository {
  /// Thực đơn của một kiosk: mỗi món thuộc đúng một kiosk (`MenuItem.kioskId`).
  Stream<List<MenuItem>> watchMenu(String kioskId);
  Future<MenuItem?> getItem(String id);
  Stream<List<Kiosk>> watchKiosks();
  Future<Voucher?> getVoucher(String code);

  /// Người bán.
  Future<void> upsertItem(MenuItem item);
  Future<void> setSoldOut(String id, bool soldOut);
}
