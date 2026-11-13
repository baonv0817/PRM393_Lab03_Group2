import 'dart:async';

import 'package:breakbite/ui/cart/view_models/cart_controls.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

/// A cart whose `addItem` only finishes when the test says so, like a Firestore transaction waiting for the server.
class _SlowCart extends FakeCartRepository {
  final gate = Completer<void>();
  bool fail = false;

  @override
  Future<Result<void>> addItem(String uid, {required String kioskId, required CartItem item}) async {
    await gate.future;
    if (fail) return const Result.error(ServiceException());
    return super.addItem(uid, kioskId: kioskId, item: item);
  }
}

const _dish = MenuItem(
  id: 'm1',
  kioskId: 'q9-t2',
  name: 'Combo Tacos Bò Phô Mai',
  priceVnd: 39000,
  category: ItemCategory.food,
  prepMinutes: 4,
  imageUrl: 'assets/images/tacos.jpg',
);

CartControls _controls(FakeCartRepository cart, void Function() onChanged) => CartControls(
  cart: cart,
  analytics: FakeAnalyticsService(),
  crash: FakeCrashService(),
  uid: 'u1',
  source: 'test',
  onChanged: onChanged,
);

void main() {
  group('adding to the cart', () {
    test('the cart button and the count show at once, before the server has answered', () async {
      final cart = _SlowCart();
      var changes = 0;
      final controls = _controls(cart, () => changes++)..start();
      await pumpEventQueue();
      expect(controls.count, 0);

      final done = controls.add(_dish);
      expect(controls.count, 1, reason: 'no waiting for the transaction');
      expect(controls.quantityOf('m1'), 1);
      expect(changes, greaterThan(0));

      cart.gate.complete();
      await done;
      await pumpEventQueue();
      expect(controls.count, 1, reason: 'the real line replaces the early one without counting twice');
      controls.stop();
    });

    test('a second tap on the same dish counts again at once', () async {
      final cart = _SlowCart();
      final controls = _controls(cart, () {})..start();
      final first = controls.add(_dish);
      final second = controls.add(_dish);
      expect(controls.count, 2);
      expect(controls.quantityOf('m1'), 2);
      cart.gate.complete();
      await Future.wait([first, second]);
      await pumpEventQueue();
      expect(controls.count, 2);
      controls.stop();
    });

    test('when the write fails the early count goes away', () async {
      final cart = _SlowCart()..fail = true;
      final controls = _controls(cart, () {})..start();
      final done = controls.add(_dish);
      expect(controls.count, 1);
      cart.gate.complete();
      final result = await done;
      expect(result, isA<Err<void>>());
      expect(controls.count, 0);
      controls.stop();
    });

    test('a dish of another kiosk is not counted early: the cart refuses it', () async {
      final cart = FakeCartRepository();
      await cart.addItem(
        'u1',
        kioskId: 'q9-t4',
        item: const CartItem(itemId: 'x', name: 'Món khác', priceVnd: 10000),
      );
      final controls = _controls(cart, () {})..start();
      await pumpEventQueue();
      expect(controls.count, 1);
      final result = await controls.add(_dish);
      expect(result, isA<Err<void>>());
      expect(controls.count, 1);
      controls.stop();
    });
  });
}
