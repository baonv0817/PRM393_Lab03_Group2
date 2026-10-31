import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/models/models.dart';

import 'live_value.dart';

class FakeCartRepository implements CartRepository {
  final _carts = <String, LiveValue<List<CartItem>>>{};

  LiveValue<List<CartItem>> _of(String uid) => _carts.putIfAbsent(uid, () => LiveValue(const []));

  @override
  Stream<List<CartItem>> watchCart(String uid) => _of(uid).stream;

  @override
  Future<void> addItem(String uid, CartItem item) async {
    final cart = _of(uid);
    final list = [...cart.value];
    final i = list.indexWhere((e) => e.itemId == item.itemId);
    i == -1 ? list.add(item) : list[i] = list[i].copyWith(quantity: list[i].quantity + item.quantity);
    cart.set(list);
  }

  @override
  Future<void> setQuantity(String uid, String itemId, int quantity) async {
    final cart = _of(uid);
    cart.set([
      for (final e in cart.value)
        if (e.itemId != itemId) e else if (quantity > 0) e.copyWith(quantity: quantity),
    ]);
  }

  @override
  Future<void> clear(String uid) async => _of(uid).set(const []);
}
