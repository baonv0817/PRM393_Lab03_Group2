import 'dart:async';

import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/seller_menu/view_models/seller_menu_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

class _FailingMenu extends FakeMenuRepository {
  @override
  Stream<List<MenuItem>> watchMenu(String kioskId) => Stream.error(const NetworkException());
}

class _OfflineWrite extends FakeMenuRepository {
  @override
  Future<Result<void>> setSoldOut(String id, bool soldOut, {SoldOutReason? reason, DateTime? availableAgainAt}) async =>
      const Result.error(NetworkException());
}

class _SlowWrite extends FakeMenuRepository {
  final release = Completer<void>();
  int writes = 0;

  @override
  Future<Result<void>> setSoldOut(String id, bool soldOut, {SoldOutReason? reason, DateTime? availableAgainAt}) async {
    writes++;
    await release.future;
    return super.setSoldOut(id, soldOut, reason: reason, availableAgainAt: availableAgainAt);
  }
}

// "Now" is 9:00; the sold-out item of the fake menu is expected back at 10:30.
final _now = DateTime(2026, 11, 2, 9);

SellerMenuViewModel _vm(FakeMenuRepository menu, {String? kioskId = 'q9-t2', FakeCrashService? crash, DateTime? now}) =>
    SellerMenuViewModel(menu: menu, crash: crash ?? FakeCrashService(), kioskId: kioskId, clock: () => now ?? _now);

List<String> _names(Iterable<MenuItem> items) => items.map((i) => i.name).toList();

void main() {
  group('SellerMenuViewModel', () {
    test('lists the items of the staff member\'s kiosk by category, with how many are sold out', () async {
      final vm = _vm(FakeMenuRepository());
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<List<MenuItem>>>());
      expect(vm.kioskName, 'Kiosk Q9 · Tầng 2');
      expect((vm.availableCount, vm.soldOutCount), (3, 1));
      expect(vm.summary, '4 món · 1 hết hàng');
      expect((vm.hasKiosk, vm.canAdd), (true, true));
      expect(vm.groups.map((g) => g.label), ['Món ăn', 'Đồ uống']);
      expect(_names(vm.groups.first.items), [
        'Combo Tacos Bò Phô Mai',
        'Mì Trộn Gà Cay Hàn Quốc',
        'Tacos Gà Giòn Sốt Cay',
      ]);
      expect(_names(vm.groups.last.items), ['Trà Đào Chanh Sả']);
      vm.dispose();
    });

    test('the filter shows only what is on sale or only what is sold out', () async {
      final vm = _vm(FakeMenuRepository());
      await pumpEventQueue();

      vm.setFilter(SellerMenuFilter.available);
      expect(vm.groups.expand((g) => g.items).where((i) => i.soldOut), isEmpty);
      expect(vm.groups.expand((g) => g.items), hasLength(3));

      vm.setFilter(SellerMenuFilter.soldOut);
      expect(_names(vm.groups.expand((g) => g.items)), ['Tacos Gà Giòn Sốt Cay']);
      expect(vm.emptyFilterMessage, isNull);
      vm.dispose();
    });

    test('a filter that matches nothing says so', () async {
      final menu = FakeMenuRepository();
      final vm = _vm(menu);
      await pumpEventQueue();

      await vm.markAvailable(vm.groups.first.items.last);
      await pumpEventQueue();
      vm.setFilter(SellerMenuFilter.soldOut);
      expect(vm.groups, isEmpty);
      expect(vm.emptyFilterMessage, 'Chưa có món nào hết hàng.');

      for (final id in ['m1', 'm2', 'm3', 'm4']) {
        await menu.setSoldOut(id, true);
      }
      await pumpEventQueue();
      vm.setFilter(SellerMenuFilter.available);
      expect(vm.emptyFilterMessage, 'Hiện không có món nào đang bán.');
      vm.dispose();
    });

    test(
      'setting an item sold out stores the reason and the time it is expected back, and says so in its row',
      () async {
        final menu = FakeMenuRepository();
        final vm = _vm(menu);
        await pumpEventQueue();
        final item = vm.groups.first.items.first;

        final result = await vm.markSoldOut(
          item,
          reason: SoldOutReason.outOfIngredients,
          backIn: const Duration(minutes: 30),
        );
        await pumpEventQueue();

        expect(result, isA<Ok<void>>());
        final stored = (await menu.getItem('m1') as Ok<MenuItem>).value;
        expect((stored.soldOut, stored.soldOutReason), (true, SoldOutReason.outOfIngredients));
        expect(stored.availableAgainAt, DateTime(2026, 11, 2, 9, 30));
        expect(vm.statusLine(stored), 'Hết nguyên liệu · dự kiến có lại lúc 09:30');
        expect(vm.summary, '4 món · 2 hết hàng');
        vm.dispose();
      },
    );

    test('without an expected time the row only gives the reason', () async {
      final menu = FakeMenuRepository();
      final vm = _vm(menu);
      await pumpEventQueue();

      await vm.markSoldOut(vm.groups.first.items.first, reason: SoldOutReason.machineBroken);
      final stored = (await menu.getItem('m1') as Ok<MenuItem>).value;
      expect(stored.availableAgainAt, isNull);
      expect(vm.statusLine(stored), 'Máy móc hỏng');
      vm.dispose();
    });

    test('putting an item back on sale drops its reason and expected time', () async {
      final menu = FakeMenuRepository();
      final vm = _vm(menu);
      await pumpEventQueue();
      await vm.markSoldOut(vm.groups.first.items.first, reason: SoldOutReason.other, backIn: const Duration(hours: 1));

      final soldItem = (await menu.getItem('m1') as Ok<MenuItem>).value;
      final result = await vm.markAvailable(soldItem);
      final stored = (await menu.getItem('m1') as Ok<MenuItem>).value;

      expect(result, isA<Ok<void>>());
      expect((stored.soldOut, stored.soldOutReason, stored.availableAgainAt), (false, null, null));
      expect(vm.statusLine(stored), 'Đang bán');
      vm.dispose();
    });

    test('an item whose expected time has passed says to switch it back when there is stock', () async {
      final vm = _vm(FakeMenuRepository(), now: DateTime(2026, 11, 2, 11));
      await pumpEventQueue();
      final soldOut = vm.groups.first.items.firstWhere((i) => i.soldOut);

      expect(vm.statusLine(soldOut), 'Hết hàng · đã quá giờ dự kiến, bật lại khi có hàng');
      vm.dispose();
    });

    test('an item whose expected time is still ahead says when it is expected', () async {
      final vm = _vm(FakeMenuRepository());
      await pumpEventQueue();
      final soldOut = vm.groups.first.items.firstWhere((i) => i.soldOut);

      expect(vm.statusLine(soldOut), 'Hết hàng · dự kiến có lại lúc 10:30');
      vm.dispose();
    });

    test('while an item is being saved its switch is busy, and a second change is ignored', () async {
      final menu = _SlowWrite();
      final vm = _vm(menu);
      await pumpEventQueue();
      final item = vm.groups.first.items.first;

      final first = vm.markSoldOut(item, reason: SoldOutReason.other);
      await pumpEventQueue();
      expect(vm.isBusy('m1'), isTrue);
      expect(vm.isBusy('m2'), isFalse);

      final second = await vm.markSoldOut(item, reason: SoldOutReason.machineBroken);
      expect(second, isA<Ok<void>>());
      expect(menu.writes, 1);

      menu.release.complete();
      await first;
      await pumpEventQueue();
      expect(vm.isBusy('m1'), isFalse);
      expect((await menu.getItem('m1') as Ok<MenuItem>).value.soldOutReason, SoldOutReason.other);
      vm.dispose();
    });

    test('a failed write reports the reason, is recorded, frees the switch and leaves the item as it was', () async {
      final crash = FakeCrashService();
      final vm = _vm(_OfflineWrite(), crash: crash);
      await pumpEventQueue();
      final item = vm.groups.first.items.first;

      final result = await vm.markSoldOut(item, reason: SoldOutReason.other);
      await pumpEventQueue();

      expect((result as Err<void>).error.message, const NetworkException().message);
      expect(crash.errors, hasLength(1));
      expect(vm.isBusy('m1'), isFalse);
      expect(vm.groups.first.items.first.soldOut, isFalse);
      vm.dispose();
    });

    test('an account without a kiosk gets an explanation instead of a menu', () async {
      for (final kioskId in [null, '']) {
        final vm = _vm(FakeMenuRepository(), kioskId: kioskId);
        await pumpEventQueue();

        expect(vm.state, isA<ViewEmpty<List<MenuItem>>>());
        expect((vm.state as ViewEmpty<List<MenuItem>>).message, SellerMenuViewModel.noKioskMessage);
        expect((vm.hasKiosk, vm.canAdd), (false, false));
        vm.dispose();
      }
    });

    test('a kiosk without items is the empty state', () async {
      final vm = _vm(FakeMenuRepository(), kioskId: 'nvh-t1');
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<List<MenuItem>>>());
      expect((vm.state as ViewEmpty<List<MenuItem>>).message, SellerMenuViewModel.emptyMessage);
      expect((vm.hasKiosk, vm.canAdd), (true, false), reason: 'an empty menu offers adding in its own message');
      vm.dispose();
    });

    test('a failed load is an error with the reason, it is recorded, and retry loads again', () async {
      final crash = FakeCrashService();
      final vm = _vm(_FailingMenu(), crash: crash);
      await pumpEventQueue();

      expect(vm.state, isA<ViewError<List<MenuItem>>>());
      expect((vm.state as ViewError<List<MenuItem>>).message, const NetworkException().message);
      expect(crash.errors, hasLength(1));

      vm.load();
      expect(vm.state, isA<ViewLoading<List<MenuItem>>>());
      await pumpEventQueue();
      expect(vm.state, isA<ViewError<List<MenuItem>>>());
      vm.dispose();
    });
  });
}
