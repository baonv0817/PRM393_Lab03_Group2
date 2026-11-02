import 'dart:async';

import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/seller_shop/view_models/shop_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

class _FailingKiosks extends FakeMenuRepository {
  @override
  Stream<List<Kiosk>> watchKiosks() => Stream.error(const NetworkException());
}

class _OfflineWrite extends FakeMenuRepository {
  @override
  Future<Result<void>> updateKiosk(String id, KioskSettings settings) async => const Result.error(NetworkException());
}

class _SlowWrite extends FakeMenuRepository {
  final release = Completer<void>();
  final written = <KioskSettings>[];

  @override
  Future<Result<void>> updateKiosk(String id, KioskSettings settings) async {
    written.add(settings);
    await release.future;
    return super.updateKiosk(id, settings);
  }
}

final _now = DateTime(2026, 11, 2, 9);

ShopViewModel _vm(FakeMenuRepository menu, {String? kioskId = 'q9-t2', FakeCrashService? crash}) =>
    ShopViewModel(menu: menu, crash: crash ?? FakeCrashService(), kioskId: kioskId, clock: () => _now);

Future<Kiosk> _kiosk(FakeMenuRepository menu) async =>
    (await menu.watchKiosks().first).firstWhere((k) => k.id == 'q9-t2');

void main() {
  group('ShopViewModel', () {
    test('shows the kiosk of the staff member', () async {
      final vm = _vm(FakeMenuRepository());
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<Kiosk>>());
      expect(vm.kiosk?.name, 'Kiosk Q9 · Tầng 2');
      expect((vm.acceptsOrders, vm.isPaused, vm.waitMinutes), (true, false, 6));
      expect(vm.statusLine, 'Mở · chờ 5–7 phút');
      vm.dispose();
    });

    test('says so when the account has no kiosk or the kiosk does not exist', () async {
      final none = _vm(FakeMenuRepository(), kioskId: null);
      expect(none.state, isA<ViewEmpty<Kiosk>>());
      expect((none.state as ViewEmpty).message, ShopViewModel.noKioskMessage);
      expect(none.hasKiosk, isFalse);

      final missing = _vm(FakeMenuRepository(), kioskId: 'gone');
      await pumpEventQueue();
      expect((missing.state as ViewEmpty).message, ShopViewModel.notFoundMessage);
      none.dispose();
      missing.dispose();
    });

    test('reports a failed load', () async {
      final crash = FakeCrashService();
      final vm = _vm(_FailingKiosks(), crash: crash);
      await pumpEventQueue();

      expect(vm.state, isA<ViewError<Kiosk>>());
      expect(crash.errors, hasLength(1));
      vm.dispose();
    });

    group('the switch, the pause and the wait', () {
      test('closing the kiosk drops a pause and opening it again keeps the wait', () async {
        final menu = FakeMenuRepository();
        final vm = _vm(menu);
        await pumpEventQueue();
        await vm.pauseFor(const Duration(minutes: 30));
        await pumpEventQueue();
        expect(vm.isPaused, isTrue);

        await vm.setOpen(false);
        await pumpEventQueue();
        var kiosk = await _kiosk(menu);
        expect((kiosk.open, kiosk.pausedUntil, kiosk.waitMinutes), (false, null, 6));
        expect(vm.acceptsOrders, isFalse);
        expect(vm.statusLine, 'Đang đóng cửa');

        await vm.setOpen(true);
        await pumpEventQueue();
        kiosk = await _kiosk(menu);
        expect((kiosk.open, kiosk.waitMinutes), (true, 6));
        vm.dispose();
      });

      test('a pause ends at the time chosen and can be ended at once', () async {
        final menu = FakeMenuRepository();
        final vm = _vm(menu);
        await pumpEventQueue();

        await vm.pauseFor(const Duration(minutes: 15));
        await pumpEventQueue();
        expect((await _kiosk(menu)).pausedUntil, DateTime(2026, 11, 2, 9, 15));
        expect((vm.isPaused, vm.acceptsOrders), (true, false));
        expect(vm.statusLine, 'Tạm ngưng · nhận đơn lại lúc 09:15');

        await vm.resume();
        await pumpEventQueue();
        expect((await _kiosk(menu)).pausedUntil, isNull);
        expect((vm.isPaused, vm.acceptsOrders), (false, true));
        vm.dispose();
      });

      test('pausing opens a kiosk that was closed', () async {
        final menu = FakeMenuRepository();
        final vm = _vm(menu);
        await pumpEventQueue();
        await vm.setOpen(false);
        await pumpEventQueue();

        await vm.pauseFor(const Duration(hours: 1));
        await pumpEventQueue();

        expect((await _kiosk(menu)).open, isTrue);
        vm.dispose();
      });

      test('the wait moves a minute at a time between 0 and the limit', () async {
        final menu = FakeMenuRepository();
        final vm = _vm(menu);
        await pumpEventQueue();

        await vm.changeWait(1);
        await pumpEventQueue();
        expect(vm.waitMinutes, 7);

        for (var i = 0; i < 10; i++) {
          await vm.changeWait(-1);
          await pumpEventQueue();
        }
        expect((vm.waitMinutes, vm.canLowerWait, vm.canRaiseWait), (0, false, true));

        await vm.changeWait(KioskSettings.maxWaitMinutes + 50);
        await pumpEventQueue();
        expect((vm.waitMinutes, vm.canRaiseWait), (KioskSettings.maxWaitMinutes, false));
        vm.dispose();
      });

      test('keeps the notice and hours when only the switch changes', () async {
        final menu = FakeMenuRepository();
        await menu.updateKiosk(
          'q9-t2',
          const KioskSettings(open: true, waitMinutes: 6, notice: 'Hết sốt', openTime: '06:30', maxOrdersPerSlot: 5),
        );
        final vm = _vm(menu);
        await pumpEventQueue();

        await vm.setOpen(false);
        await pumpEventQueue();

        final kiosk = await _kiosk(menu);
        expect((kiosk.notice, kiosk.openTime, kiosk.maxOrdersPerSlot), ('Hết sốt', '06:30', 5));
        vm.dispose();
      });

      test('ignores a second tap while a write is running, so it cannot overwrite with stale values', () async {
        final menu = _SlowWrite();
        final vm = _vm(menu);
        await pumpEventQueue();

        final first = vm.changeWait(1);
        await vm.changeWait(1);
        expect(vm.applying, isTrue);
        menu.release.complete();
        await first;
        await pumpEventQueue();

        expect(menu.written, hasLength(1));
        expect(vm.waitMinutes, 7);
        expect(vm.applying, isFalse);
        vm.dispose();
      });

      test('returns the error and records it when the write fails', () async {
        final crash = FakeCrashService();
        final vm = _vm(_OfflineWrite(), crash: crash);
        await pumpEventQueue();

        final result = await vm.setOpen(false);

        expect((result as Err<void>).error, isA<NetworkException>());
        expect(vm.kiosk?.open, isTrue);
        expect(vm.applying, isFalse);
        expect(crash.errors, hasLength(1));
        vm.dispose();
      });
    });

    group('the info form', () {
      test('starts with what the kiosk has and is not dirty', () async {
        final menu = FakeMenuRepository();
        await menu.updateKiosk(
          'q9-t2',
          const KioskSettings(
            open: true,
            waitMinutes: 6,
            notice: 'Hết sốt',
            openTime: '06:30',
            closeTime: '17:00',
            maxOrdersPerSlot: 5,
          ),
        );
        final vm = _vm(menu);
        await pumpEventQueue();

        expect((vm.notice, vm.openTime, vm.closeTime, vm.maxOrders), ('Hết sốt', '06:30', '17:00', '5'));
        expect((vm.infoDirty, vm.infoValid), (false, true));
        vm.dispose();
      });

      test('shows field errors only after a save was tried, and writes nothing while one is wrong', () async {
        final menu = FakeMenuRepository();
        final vm = _vm(menu);
        await pumpEventQueue();

        vm.setOpenTime('6:30');
        vm.setCloseTime('25:00');
        vm.setMaxOrders('0');
        expect(vm.infoValid, isFalse);
        expect(vm.showErrors, isFalse);

        final result = await vm.saveInfo.execute();

        expect((result as Err<void>).error.message, ShopViewModel.invalidMessage);
        expect(vm.showErrors, isTrue);
        expect((vm.openTimeError, vm.closeTimeError), ('Nhập giờ dạng 06:30.', 'Nhập giờ dạng 06:30.'));
        expect(vm.maxOrdersError, contains('1 đến'));
        expect((await _kiosk(menu)).openTime, isNull);
        vm.dispose();
      });

      test('rejects a notice that is too long and a capacity above the limit', () async {
        final vm = _vm(FakeMenuRepository());
        await pumpEventQueue();

        vm.setNotice('x' * (KioskSettings.maxNoticeLength + 1));
        vm.setMaxOrders('${ShopViewModel.maxOrdersLimit + 1}');

        expect(vm.noticeError, isNotNull);
        expect(vm.maxOrdersError, isNotNull);
        vm.setNotice('x' * KioskSettings.maxNoticeLength);
        vm.setMaxOrders('${ShopViewModel.maxOrdersLimit}');
        expect(vm.infoValid, isTrue);
        vm.dispose();
      });

      test('saves the notice, hours and capacity, and empty fields remove them', () async {
        final menu = FakeMenuRepository();
        final vm = _vm(menu);
        await pumpEventQueue();

        vm.setNotice('  Hết sốt phô mai  ');
        vm.setOpenTime('06:30');
        vm.setCloseTime('17:00');
        vm.setMaxOrders('8');
        expect(vm.infoDirty, isTrue);
        expect((await vm.saveInfo.execute())?.isOk, isTrue);
        await pumpEventQueue();

        var kiosk = await _kiosk(menu);
        expect(
          (kiosk.notice, kiosk.openTime, kiosk.closeTime, kiosk.maxOrdersPerSlot),
          ('Hết sốt phô mai', '06:30', '17:00', 8),
        );
        expect((kiosk.open, kiosk.waitMinutes), (true, 6));
        expect((vm.infoDirty, vm.showErrors), (false, false));

        vm.setNotice('');
        vm.setOpenTime('');
        vm.setCloseTime('');
        vm.setMaxOrders('');
        await vm.saveInfo.execute();
        await pumpEventQueue();

        kiosk = await _kiosk(menu);
        expect((kiosk.notice, kiosk.openTime, kiosk.closeTime, kiosk.maxOrdersPerSlot), (null, null, null, null));
        vm.dispose();
      });

      test('saving does not undo a pause or a wait set in the meantime', () async {
        final menu = FakeMenuRepository();
        final vm = _vm(menu);
        await pumpEventQueue();
        vm.setNotice('Hết sốt');

        await vm.pauseFor(const Duration(minutes: 30));
        await vm.changeWait(3);
        await pumpEventQueue();
        await vm.saveInfo.execute();
        await pumpEventQueue();

        final kiosk = await _kiosk(menu);
        expect((kiosk.notice, kiosk.waitMinutes, kiosk.pausedUntil), ('Hết sốt', 9, DateTime(2026, 11, 2, 9, 30)));
        vm.dispose();
      });

      test('keeps what was typed and reports the error when the save fails', () async {
        final crash = FakeCrashService();
        final vm = _vm(_OfflineWrite(), crash: crash);
        await pumpEventQueue();
        vm.setNotice('Hết sốt');

        final result = await vm.saveInfo.execute();

        expect((result as Err<void>).error, isA<NetworkException>());
        expect((vm.notice, vm.infoDirty), ('Hết sốt', true));
        expect(crash.errors, hasLength(1));
        vm.dispose();
      });

      test('what was typed survives a change of the kiosk made elsewhere', () async {
        final menu = FakeMenuRepository();
        final vm = _vm(menu);
        await pumpEventQueue();
        vm.setNotice('Đang gõ dở');

        await menu.updateKiosk('q9-t2', const KioskSettings(open: false, waitMinutes: 6, notice: 'Từ máy khác'));
        await pumpEventQueue();

        expect(vm.notice, 'Đang gõ dở');
        expect(vm.kiosk?.open, isFalse);
        vm.dispose();
      });
    });
  });
}
