import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/order_manage/view_models/edit_order_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

class _FailingOrders extends FakeOrderRepository {
  @override
  Stream<Order?> watchOrder(String id) => Stream.error(const NetworkException());
}

class _OfflineSave extends FakeOrderRepository {
  _OfflineSave() : super(vouchers: {for (final v in fakeVouchers) v.code: v});

  @override
  Future<Result<void>> editPendingOrder(
    Order order, {
    required List<CartItem> items,
    String? voucherCode,
    String? pickupSlotId,
    String note = '',
  }) async => const Result.error(NetworkException());
}

class _UnknownVoucher extends FakeMenuRepository {
  @override
  Future<Result<Voucher>> getVoucher(String code) async =>
      const Result.error(NotFoundException(message: 'Mã giảm giá không tồn tại.'));
}

const _combo = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000, quantity: 2, note: 'Ít cay');
const _tea = CartItem(itemId: 'm2', name: 'Trà đào', priceVnd: 25000);

FakeOrderRepository _orders() => FakeOrderRepository(vouchers: {for (final v in fakeVouchers) v.code: v});

/// 2 combos with a note and a tea, BBSTUDENT: 103.000đ − 10.000đ = 93.000đ, still pending.
Future<String> _place(FakeOrderRepository orders, {String? voucher = 'BBSTUDENT', List<CartItem>? items}) async {
  final result = await orders.placeOrder(
    OrderDraft(
      uid: 'u1',
      customerName: 'Khách',
      kioskId: 'q9-t2',
      kioskName: 'Kiosk Q9 · Tầng 2',
      items: items ?? const [_combo, _tea],
      paymentMethod: PaymentMethod.momo,
      voucherCode: voucher,
      note: 'Gói riêng',
    ),
  );
  return result.valueOrNull!;
}

EditOrderViewModel _vm(OrderRepository orders, {MenuRepository? menu, FakeCrashService? crash, String id = 'A-204'}) =>
    EditOrderViewModel(
      orders: orders,
      menu: menu ?? FakeMenuRepository(),
      crash: crash ?? FakeCrashService(),
      orderId: id,
      clock: () => DateTime(2026, 11, 2, 10),
    );

void main() {
  group('EditOrderViewModel', () {
    test('starts as the order was placed: same lines, same bill, nothing to save', () async {
      final orders = _orders();
      final id = await _place(orders);
      final vm = _vm(orders, id: id);
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<Order>>());
      expect(vm.locked, isFalse);
      expect(vm.items.map((i) => (i.itemId, i.quantity, i.note)), [('m1', 2, 'Ít cay'), ('m2', 1, '')]);
      expect(vm.itemCount, 3);
      expect((vm.pricing.subtotalVnd, vm.pricing.discountVnd, vm.pricing.totalVnd), (103000, 10000, 93000));
      expect(vm.voucherCode, 'BBSTUDENT');
      expect(vm.voucherProblem, isNull);
      expect(vm.hasChanges, isFalse);
      expect(vm.canSave, isFalse);
      vm.dispose();
    });

    test('changing a quantity updates the bill, and going back to the original is no change', () async {
      final orders = _orders();
      final vm = _vm(orders, id: await _place(orders));
      await pumpEventQueue();

      vm.changeQuantity('m1', 1);
      expect(vm.items.first.quantity, 3);
      expect(vm.pricing.totalVnd, 132000);
      expect(vm.hasChanges, isTrue);
      expect(vm.canSave, isTrue);

      vm.changeQuantity('m1', -1);
      expect(vm.hasChanges, isFalse);
      expect(vm.canSave, isFalse);
      vm.dispose();
    });

    test('a quantity stops at the maximum and cannot go below one while it is the only line', () async {
      final orders = _orders();
      final vm = _vm(orders, id: await _place(orders, voucher: null, items: const [_tea]));
      await pumpEventQueue();

      expect(vm.canDecrease('m2'), isFalse);
      vm.changeQuantity('m2', -1);
      expect(vm.items.single.quantity, 1);

      vm.changeQuantity('m2', Cart.maxQuantity - 1);
      expect(vm.items.single.quantity, Cart.maxQuantity);
      expect(vm.canIncrease('m2'), isFalse);
      vm.changeQuantity('m2', 1);
      expect(vm.items.single.quantity, Cart.maxQuantity);
      vm.dispose();
    });

    test('taking a line to zero removes it when other lines remain', () async {
      final orders = _orders();
      final vm = _vm(orders, id: await _place(orders));
      await pumpEventQueue();

      expect(vm.canDecrease('m2'), isTrue);
      vm.changeQuantity('m2', -1);
      expect(vm.items.map((i) => i.itemId), ['m1']);
      expect(vm.pricing.totalVnd, 68000);
      expect(vm.hasChanges, isTrue);
      vm.dispose();
    });

    test('a note is trimmed and cut to the maximum length, and counts as a change', () async {
      final orders = _orders();
      final vm = _vm(orders, id: await _place(orders));
      await pumpEventQueue();

      vm.setNote('m2', '  ít đá  ');
      expect(vm.items.last.note, 'ít đá');
      expect(vm.hasChanges, isTrue);

      vm.setNote('m2', 'x' * (EditOrderViewModel.maxNoteLength + 20));
      expect(vm.items.last.note.length, EditOrderViewModel.maxNoteLength);

      vm.setNote('m2', '');
      expect(vm.hasChanges, isFalse);
      vm.dispose();
    });

    test('a voucher that no longer fits blocks saving until it is dropped, and can be taken back', () async {
      final orders = _orders();
      final vm = _vm(orders, id: await _place(orders));
      await pumpEventQueue();

      vm.changeQuantity('m2', -1);
      vm.changeQuantity('m1', -1);
      expect(vm.pricing.subtotalVnd, 39000);
      expect(vm.voucherProblem, 'Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT.');
      expect(vm.canSave, isFalse);

      vm.dropVoucher();
      expect(vm.voucherDropped, isTrue);
      expect(vm.voucherProblem, isNull);
      expect((vm.pricing.discountVnd, vm.pricing.totalVnd), (0, 39000));
      expect(vm.canSave, isTrue);

      vm.keepVoucher();
      expect(vm.voucherProblem, 'Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT.');
      expect(vm.canSave, isFalse);
      vm.dispose();
    });

    test('dropping the voucher alone is a change; an order without a voucher has no voucher row', () async {
      final orders = _orders();
      final vm = _vm(orders, id: await _place(orders));
      final plain = _vm(orders, id: await _place(orders, voucher: null));
      await pumpEventQueue();

      vm.dropVoucher();
      expect(vm.hasChanges, isTrue);
      expect(vm.pricing.totalVnd, 103000);
      expect(plain.voucherCode, isNull);
      expect(plain.voucherProblem, isNull);
      vm.dispose();
      plain.dispose();
    });

    test('a voucher that has been removed from the system is reported and blocks saving until dropped', () async {
      final orders = _orders();
      final vm = _vm(orders, menu: _UnknownVoucher(), id: await _place(orders));
      await pumpEventQueue();

      expect(vm.voucherProblem, 'Mã BBSTUDENT không tồn tại hoặc đã bị gỡ.');
      vm.changeQuantity('m1', 1);
      expect(vm.canSave, isFalse);
      vm.dropVoucher();
      expect(vm.canSave, isTrue);
      vm.dispose();
    });

    test('saving writes the new lines and bill and keeps the voucher, note and pickup of the order', () async {
      final orders = _orders();
      final id = await _place(orders);
      final vm = _vm(orders, id: id);
      await pumpEventQueue();

      vm.changeQuantity('m1', 1);
      vm.setNote('m2', 'ít đá');
      final result = await vm.save.execute();
      await pumpEventQueue();

      expect(result, isA<Ok<void>>());
      final saved = orders.all.single;
      expect(saved.items.map((i) => (i.itemId, i.quantity, i.note)), [('m1', 3, 'Ít cay'), ('m2', 1, 'ít đá')]);
      expect((saved.subtotalVnd, saved.discountVnd, saved.totalVnd), (142000, 10000, 132000));
      expect(saved.voucherCode, 'BBSTUDENT');
      expect(saved.note, 'Gói riêng');
      expect(vm.hasChanges, isFalse);
      vm.dispose();
    });

    test('saving with the voucher dropped removes it from the order', () async {
      final orders = _orders();
      final id = await _place(orders);
      final vm = _vm(orders, id: id);
      await pumpEventQueue();

      vm.dropVoucher();
      final result = await vm.save.execute();

      expect(result, isA<Ok<void>>());
      final saved = orders.all.single;
      expect(saved.voucherCode, isNull);
      expect((saved.discountVnd, saved.totalVnd), (0, 103000));
      vm.dispose();
    });

    test('when the kitchen takes the order the screen locks, and nothing more can be changed or saved', () async {
      final orders = _orders();
      final id = await _place(orders);
      final vm = _vm(orders, id: id);
      await pumpEventQueue();
      expect(vm.locked, isFalse);

      await orders.accept(orders.all.single, readyIn: const Duration(minutes: 5));
      await pumpEventQueue();
      expect(vm.locked, isTrue);

      vm.changeQuantity('m1', 1);
      vm.setNote('m1', 'đổi ý');
      expect(vm.items.first.quantity, 2);
      expect(vm.items.first.note, 'Ít cay');
      expect(vm.canSave, isFalse);
      final result = await vm.save.execute();
      expect((result! as Err<void>).error.message, EditOrderViewModel.lockedMessage);
      vm.dispose();
    });

    test('an order that was already taken when the screen opened is locked from the start', () async {
      final orders = _orders();
      final id = await _place(orders);
      await orders.accept(orders.all.single, readyIn: const Duration(minutes: 5));
      final vm = _vm(orders, id: id);
      await pumpEventQueue();

      expect(vm.locked, isTrue);
      expect(vm.items, isEmpty);
      expect(vm.canSave, isFalse);
      vm.dispose();
    });

    test('a failed save reports the reason, is recorded, and keeps the changes', () async {
      final orders = _OfflineSave();
      final id = await _place(orders);
      final crash = FakeCrashService();
      final vm = _vm(orders, crash: crash, id: id);
      await pumpEventQueue();

      vm.changeQuantity('m1', 1);
      final result = await vm.save.execute();

      expect((result! as Err<void>).error.message, const NetworkException().message);
      expect(crash.errors, hasLength(1));
      expect(vm.items.first.quantity, 3);
      expect(vm.canSave, isTrue);
      vm.dispose();
    });

    test('an unknown order id is the empty state', () async {
      final vm = _vm(FakeOrderRepository(), id: 'nope');
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<Order>>());
      expect((vm.state as ViewEmpty<Order>).message, EditOrderViewModel.notFoundMessage);
      expect(vm.canSave, isFalse);
      final result = await vm.save.execute();
      expect((result! as Err<void>).error.message, EditOrderViewModel.notFoundMessage);
      vm.dispose();
    });

    test('a failed load is an error with the reason, it is recorded, and retry loads again', () async {
      final crash = FakeCrashService();
      final vm = _vm(_FailingOrders(), crash: crash);
      await pumpEventQueue();

      expect(vm.state, isA<ViewError<Order>>());
      expect((vm.state as ViewError<Order>).message, const NetworkException().message);
      expect(crash.errors, hasLength(1));

      vm.load();
      expect(vm.state, isA<ViewLoading<Order>>());
      await pumpEventQueue();
      expect(vm.state, isA<ViewError<Order>>());
      vm.dispose();
    });

    test('the fake refuses a voucher the new items no longer meet, as the real repository does', () async {
      final orders = _orders();
      final id = await _place(orders);
      final result = await orders.editPendingOrder(
        orders.all.single,
        items: const [CartItem(itemId: 'm2', name: 'Trà đào', priceVnd: 25000)],
        voucherCode: 'BBSTUDENT',
      );

      expect((result as Err<void>).error.message, 'Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT.');
      expect(orders.all.firstWhere((o) => o.id == id).items, hasLength(2));
    });
  });
}
