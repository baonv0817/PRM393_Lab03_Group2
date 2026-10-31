import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';

class FakeCartRepository implements CartRepository {
  final _carts = <String, LiveValue<List<CartItem>>>{};

  LiveValue<List<CartItem>> _of(String uid) => _carts.putIfAbsent(uid, () => LiveValue(const []));

  @override
  Stream<List<CartItem>> watchCart(String uid) => _of(uid).stream;

  @override
  Future<Result<void>> addItem(String uid, CartItem item) async {
    final cart = _of(uid);
    final list = [...cart.value];
    final i = list.indexWhere((e) => e.itemId == item.itemId);
    i == -1 ? list.add(item) : list[i] = list[i].copyWith(quantity: list[i].quantity + item.quantity);
    cart.set(list);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setQuantity(String uid, String itemId, int quantity) async {
    final cart = _of(uid);
    cart.set([
      for (final e in cart.value)
        if (e.itemId != itemId) e else if (quantity > 0) e.copyWith(quantity: quantity),
    ]);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> clear(String uid) async {
    _of(uid).set(const []);
    return const Result.ok(null);
  }
}
