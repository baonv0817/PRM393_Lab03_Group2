import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';

class FakeMenuRepository implements MenuRepository {
  final _menu = LiveValue<List<MenuItem>>(const [
    MenuItem(
      id: 'm1',
      name: 'Combo Tacos Bò Phô Mai',
      priceVnd: 39000,
      category: 'Tacos',
      prepMinutes: 4,
      kioskId: 'q9-t2',
      imageUrl: 'assets/images/menu/tacos-bo.jpg',
    ),
    MenuItem(
      id: 'm2',
      name: 'Mì Trộn Gà Cay Hàn Quốc',
      priceVnd: 35000,
      category: 'Mì trộn',
      prepMinutes: 5,
      kioskId: 'q9-t2',
      imageUrl: 'assets/images/menu/mi-tron-ga.jpg',
    ),
    MenuItem(
      id: 'm3',
      name: 'Trà Đào Chanh Sả',
      priceVnd: 20000,
      category: 'Đồ uống',
      prepMinutes: 2,
      kioskId: 'q9-t2',
      imageUrl: 'assets/images/menu/tra-dao.jpg',
    ),
    MenuItem(
      id: 'm4',
      name: 'Tacos Gà Giòn Sốt Cay',
      priceVnd: 35000,
      category: 'Tacos',
      prepMinutes: 4,
      soldOut: true,
      kioskId: 'q9-t2',
      imageUrl: 'assets/images/menu/tacos-ga.jpg',
    ),
    MenuItem(
      id: 'm5',
      name: 'Bánh Mì Chả Lụa Trứng',
      priceVnd: 22000,
      category: 'Bánh mì',
      prepMinutes: 3,
      kioskId: 'q9-t4',
      imageUrl: 'assets/images/menu/banh-mi.jpg',
    ),
    MenuItem(
      id: 'm6',
      name: 'Cà Phê Sữa Đá',
      priceVnd: 18000,
      category: 'Đồ uống',
      prepMinutes: 2,
      kioskId: 'q9-t4',
      imageUrl: 'assets/images/menu/cafe-sua.jpg',
    ),
  ]);
  final _kiosks = LiveValue<List<Kiosk>>(const [
    Kiosk(id: 'q9-t2', name: 'Kiosk Q9 · Tầng 2', open: true, waitMinutes: 6),
    Kiosk(id: 'q9-t4', name: 'Kiosk Q9 · Tầng 4', open: true, waitMinutes: 10),
    Kiosk(id: 'nvh-t1', name: 'Nhà văn hóa SV · Tầng 1', open: false, waitMinutes: 0),
  ]);

  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) =>
      _menu.stream.map((items) => items.where((e) => e.kioskId == kioskId).toList());

  @override
  Future<Result<MenuItem>> getItem(String id) async {
    final item = _menu.value.where((e) => e.id == id).firstOrNull;
    return item == null ? const Result.error(NotFoundException(message: 'Không tìm thấy món.')) : Result.ok(item);
  }

  @override
  Stream<List<Kiosk>> watchKiosks() => _kiosks.stream;

  @override
  Future<Result<Voucher>> getVoucher(String code) async => switch (code) {
    'BBSTUDENT' => Result.ok(Voucher(code: code, discountVnd: 10000, expiresAt: DateTime(2100), minOrderVnd: 40000)),
    'BB20' => Result.ok(Voucher(code: code, discountVnd: 20000, expiresAt: DateTime(2020), minOrderVnd: 0)),
    _ => const Result.error(NotFoundException(message: 'Mã giảm giá không tồn tại.')),
  };

  @override
  Future<Result<void>> upsertItem(MenuItem item) async {
    final list = [..._menu.value];
    final i = list.indexWhere((e) => e.id == item.id);
    i == -1 ? list.add(item) : list[i] = item;
    _menu.set(list);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setSoldOut(String id, bool soldOut) async {
    _menu.set([for (final e in _menu.value) e.id == id ? e.copyWith(soldOut: soldOut) : e]);
    return const Result.ok(null);
  }
}
