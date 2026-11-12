import 'package:breakbite/ui/cart/view_models/pickup_time_view_model.dart';
import 'package:breakbite/ui/cart/view_models/voucher_picker_view_model.dart';
import 'package:breakbite/ui/orders/view_models/orders_view_model.dart';
import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

const _tacos = CartItem(itemId: 'm1', name: 'Combo Tacos Bò Phô Mai', priceVnd: 39000);
final _tenAmInVietnam = DateTime.utc(2026, 11, 2, 3);
final _goldenHourInVietnam = DateTime.utc(2026, 11, 2, 3, 20);

Future<FakeCartRepository> _cartWith(int quantity, {String? voucher}) async {
  final cart = FakeCartRepository();
  await cart.addItem(
    'u1',
    kioskId: 'q9-t2',
    item: _tacos.copyWith(quantity: quantity),
  );
  if (voucher != null) await cart.setVoucher('u1', voucher);
  return cart;
}

void main() {
  group('VoucherPickerViewModel', () {
    VoucherPickerViewModel build(FakeCartRepository cart, DateTime now) => VoucherPickerViewModel(
      vouchers: FakeVoucherRepository(),
      menu: FakeMenuRepository(),
      cart: cart,
      crash: FakeCrashService(),
      uid: 'u1',
      clock: () => now,
    );

    test('usable vouchers come first; the others say what is missing; expired ones go last', () async {
      final vm = build(await _cartWith(1), _tenAmInVietnam);
      await pumpEventQueue();
      final options = vm.state.dataOrNull!;
      expect(options.map((o) => o.voucher.code), ['BBSTUDENT', 'GIOVANG', 'BB20']);
      expect(options.every((o) => !o.usable), isTrue);
      expect(vm.conditionOf(options[0]), 'Mua thêm 1.000đ để dùng mã');
      expect(vm.conditionOf(options[1]), 'Chỉ áp dụng 10:15–10:30');
      expect(vm.conditionOf(options[2]), 'Đã hết hạn');
      vm.select(options[0]);
      expect(vm.selected, isNull);
      expect(vm.canConfirm, isFalse);
      vm.dispose();
    });

    test('choosing a usable voucher and confirming applies it to the cart', () async {
      final cart = await _cartWith(2);
      final vm = build(cart, _goldenHourInVietnam);
      await pumpEventQueue();
      final options = vm.state.dataOrNull!;
      expect(options.where((o) => o.usable).map((o) => o.voucher.code), ['BBSTUDENT', 'GIOVANG']);
      expect(vm.conditionOf(options.first), 'Dùng được ngay');
      vm.select(options.firstWhere((o) => o.voucher.code == 'GIOVANG'));
      expect(vm.confirmLabel, 'Dùng mã đã chọn');
      expect(await vm.confirm.execute(), isA<Ok<void>>());
      expect(cart.current('u1').voucherCode, 'GIOVANG');
      vm.dispose();
    });

    test('a typed code is checked first: unknown and expired codes show why and change nothing', () async {
      final cart = await _cartWith(2);
      final vm = build(cart, _goldenHourInVietnam);
      await pumpEventQueue();
      await vm.applyCode.execute('nope99');
      expect(vm.codeError, 'Mã giảm giá không tồn tại.');
      await vm.applyCode.execute('bb20');
      expect(vm.codeError, 'Mã BB20 đã hết hạn.');
      expect(cart.current('u1').voucherCode, isNull);
      vm.clearCodeError();
      expect(await vm.applyCode.execute(' bbstudent '), isA<Ok<void>>());
      expect(vm.codeError, isNull);
      expect(cart.current('u1').voucherCode, 'BBSTUDENT');
      vm.dispose();
    });

    test('the applied voucher starts selected; unselecting it removes it from the cart', () async {
      final cart = await _cartWith(2, voucher: 'BBSTUDENT');
      final vm = build(cart, _goldenHourInVietnam);
      await pumpEventQueue();
      expect(vm.selected, 'BBSTUDENT');
      vm.select(vm.state.dataOrNull!.first);
      expect(vm.confirmLabel, 'Không dùng mã');
      await vm.confirm.execute();
      expect(cart.current('u1').voucherCode, isNull);
      vm.dispose();
    });
  });

  group('PickupTimeViewModel', () {
    final now = DateTime(2026, 11, 2, 10);

    PickupTimeViewModel build(FakeCartRepository cart, {DateTime? at, FakeRemoteConfigService? rc}) {
      final clock = at ?? now;
      return PickupTimeViewModel(
        slots: FakeSlotRepository(clock: () => clock),
        cart: cart,
        menu: FakeMenuRepository(),
        remoteConfig: rc ?? FakeRemoteConfigService(),
        crash: FakeCrashService(),
        uid: 'u1',
        clock: () => clock,
      );
    }

    test('upcoming break slots are grouped by day; full and too-soon slots cannot be picked', () async {
      final vm = build(await _cartWith(1), at: DateTime(2026, 11, 2, 10, 12));
      await pumpEventQueue();
      final days = vm.state.dataOrNull!;
      expect(days.map((d) => d.label), ['Hôm nay', 'Ngày mai', 'Thứ 4 04/11']);
      final today = days.first.slots;
      expect(today.map((s) => s.id), ['20261102-1015', '20261102-1315', '20261102-1445']);
      expect(vm.slotNote(today[0]), 'Không kịp');
      expect(vm.slotNote(today[1]), 'Đã đủ');
      expect(vm.slotNote(today[2]), '');
      vm.choose(today[1]);
      expect(vm.selectedId, isNull);
      expect(vm.asapLabel, 'Sớm nhất · khoảng 6 phút nữa');
      vm.dispose();
    });

    test('choosing a slot and confirming books it on the cart; going back to as soon as possible clears it', () async {
      final cart = await _cartWith(1);
      final vm = build(cart);
      await pumpEventQueue();
      final slot = vm.state.dataOrNull!.first.slots.last;
      vm.choose(slot);
      expect(vm.summary, startsWith('Nhận lúc 14:45–15:00'));
      await vm.confirm.execute();
      expect(cart.current('u1').pickupSlotId, '20261102-1445');
      expect(cart.current('u1').pickupAt, DateTime(2026, 11, 2, 14, 45));
      vm.chooseAsap();
      await vm.confirm.execute();
      expect(cart.current('u1').pickupSlotId, isNull);
      vm.dispose();
    });

    test('an empty cart has nothing to schedule; a switched-off feature cannot be confirmed', () async {
      final empty = build(FakeCartRepository());
      await pumpEventQueue();
      expect(empty.state, isA<ViewEmpty<List<PickupDay>>>());
      empty.dispose();

      final rc = FakeRemoteConfigService()..values[RemoteKeys.pickupSlotEnabled] = false;
      final off = build(await _cartWith(1), rc: rc);
      await pumpEventQueue();
      expect(off.enabled, isFalse);
      expect(off.canConfirm, isFalse);
      off.dispose();
    });
  });

  group('OrdersViewModel', () {
    OrdersViewModel build(FakeOrderRepository orders, {FakeCartRepository? cart, InMemorySessionRepository? session}) =>
        OrdersViewModel(
          orders: orders,
          cart: cart ?? FakeCartRepository(),
          session: session ?? InMemorySessionRepository(),
          analytics: FakeAnalyticsService(),
          crash: FakeCrashService(),
          uid: 'u1',
          clock: () => DateTime(2026, 11, 2, 10),
        );

    test('no order yet is the empty state', () async {
      final vm = build(FakeOrderRepository());
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<List<Order>>>());
      expect(vm.active, isEmpty);
      vm.dispose();
    });

    test('orders in progress and finished orders are split, each with what happens next', () async {
      final orders = FakeOrderRepository();
      final doneId = await placeTestOrder(orders, uid: 'u1');
      final cancelledId = await placeTestOrder(orders, uid: 'u1');
      final activeId = await placeTestOrder(orders, uid: 'u1', method: PaymentMethod.cash);
      Order find(String id) => orders.all.firstWhere((o) => o.id == id);
      await orders.accept(find(doneId), readyIn: const Duration(minutes: 3));
      await orders.markReady(find(doneId));
      await orders.deliver(find(doneId));
      await orders.cancelMyOrder(find(cancelledId));
      final vm = build(orders);
      await pumpEventQueue();
      expect(vm.active.map((o) => o.id), [activeId]);
      expect(vm.finished.map((o) => o.id), containsAll([doneId, cancelledId]));
      expect(vm.timing(find(activeId)), 'Chờ kiosk nhận đơn');
      expect(vm.timing(find(cancelledId)), 'Đã huỷ');
      expect(vm.timing(find(doneId)), startsWith('Đã nhận '));
      expect(vm.title(find(activeId)), '#$activeId · Kiosk');
      vm.dispose();
    });

    test('reordering a finished order fills the cart and selects its kiosk', () async {
      final orders = FakeOrderRepository();
      final id = await placeTestOrder(orders, uid: 'u1', kioskId: 'q9-t4');
      await orders.cancelMyOrder(orders.all.single);
      final cart = FakeCartRepository();
      final session = InMemorySessionRepository();
      final vm = build(orders, cart: cart, session: session);
      await pumpEventQueue();
      final result = await vm.reorder.execute(orders.all.firstWhere((o) => o.id == id));
      expect(result, isA<Ok<int>>());
      expect(cart.current('u1').kioskId, 'q9-t4');
      expect(await session.watchSelectedKioskId().first, 'q9-t4');
      vm.dispose();
    });
  });
}
