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

  Future<Result<void>> setSoldOut(String id, bool soldOut);
}
