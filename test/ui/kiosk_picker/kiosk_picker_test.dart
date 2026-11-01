import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/test_id.dart';
import 'package:breakbite/ui/kiosk_picker/view_models/kiosk_view_model.dart';
import 'package:breakbite/ui/kiosk_picker/widgets/kiosk_picker_screen.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/pump.dart';

class _BrokenKiosks extends FakeMenuRepository {
  bool broken = true;

  @override
  Stream<List<Kiosk>> watchKiosks() => broken ? Stream.error(const NetworkException()) : super.watchKiosks();
}

class KioskDeps {
  FakeMenuRepository menu = FakeMenuRepository();
  final session = InMemorySessionRepository(selectedKioskId: 'q9-t2');
  final cart = FakeCartRepository();
  final crash = FakeCrashService();

  KioskViewModel build({String uid = 'u1'}) => KioskViewModel(
    menu: menu,
    session: session,
    cart: cart,
    crash: crash,
    uid: uid,
    clock: () => DateTime(2026, 11, 2, 10),
  );
}

const _item = CartItem(itemId: 'q9-t2-tacos-bo', name: 'Tacos Bò', priceVnd: 39000);

Finder byId(String id) => find.byWidgetPredicate((w) => w is TestId && w.id == id);

Future<KioskViewModel> pumpPicker(WidgetTester tester, KioskDeps deps, {Size size = TestScreens.narrow}) async {
  final vm = deps.build();
  addTearDown(vm.dispose);
  await pumpScreen(
    tester,
    const KioskPickerScreen(),
    providers: [ChangeNotifierProvider<KioskViewModel>.value(value: vm)],
    size: size,
  );
  return vm;
}

void main() {
  group('KioskViewModel', () {
    test('lists every kiosk and starts on the kiosk already chosen', () async {
      final vm = KioskDeps().build();
      await pumpEventQueue();
      expect(vm.kiosks.dataOrNull?.map((k) => k.id), ['q9-t2', 'q9-t4', 'nvh-t1']);
      expect(vm.chosenId, 'q9-t2');
      expect(vm.canConfirm, isTrue);
      vm.dispose();
    });

    test('searching ignores accents and case, and says so when nothing matches', () async {
      final vm = KioskDeps().build();
      await pumpEventQueue();
      vm.search('nha van hoa');
      expect(vm.kiosks.dataOrNull?.single.id, 'nvh-t1');
      vm.search('TẦNG 4');
      expect(vm.kiosks.dataOrNull?.single.id, 'q9-t4');
      vm.search('thư viện');
      expect(vm.kiosks, isA<ViewEmpty<List<Kiosk>>>());
      expect((vm.kiosks as ViewEmpty<List<Kiosk>>).message, 'Không có kiosk nào khớp "thư viện".');
      vm.dispose();
    });

    test('confirming saves the choice for the whole app', () async {
      final deps = KioskDeps();
      final vm = deps.build();
      await pumpEventQueue();
      vm.choose('q9-t4');
      final result = await vm.confirm.execute();
      expect((result! as Ok<Kiosk>).value.id, 'q9-t4');
      expect(deps.session.selectedKioskId, 'q9-t4');
      vm.dispose();
    });

    test('switching away from a cart of another kiosk empties the cart; staying keeps it', () async {
      final deps = KioskDeps();
      await deps.cart.addItem('u1', kioskId: 'q9-t2', item: _item);
      final vm = deps.build();
      await pumpEventQueue();
      expect(vm.choiceEmptiesCart, isFalse);
      vm.choose('q9-t4');
      expect(vm.choiceEmptiesCart, isTrue);
      expect(vm.cartKiosk?.id, 'q9-t2');
      await vm.confirm.execute();
      await pumpEventQueue();
      expect(deps.session.selectedKioskId, 'q9-t4');
      expect(vm.choiceEmptiesCart, isFalse);
      final cart = await deps.cart.watchCart('u1').first;
      expect(cart.isEmpty, isTrue);
      vm.dispose();
    });

    test('a failed kiosk list shows an error, records it and can be retried', () async {
      final deps = KioskDeps()..menu = _BrokenKiosks();
      final vm = deps.build();
      await pumpEventQueue();
      expect(vm.kiosks, isA<ViewError<List<Kiosk>>>());
      expect(deps.crash.errors, hasLength(1));
      expect(vm.canConfirm, isFalse);
      (deps.menu as _BrokenKiosks).broken = false;
      vm.load();
      await pumpEventQueue();
      expect(vm.kiosks.dataOrNull, hasLength(3));
      vm.dispose();
    });
  });

  group('kiosk labels', () {
    final now = DateTime(2026, 11, 2, 10);

    test('open, paused and closed kiosks each say what the customer can expect', () {
      const open = Kiosk(id: 'a', name: 'A', open: true, waitMinutes: 6);
      expect(kioskStatusLabel(open, now: now), 'Mở · chờ 5–7 phút');
      final paused = Kiosk(id: 'a', name: 'A', open: true, waitMinutes: 6, pausedUntil: DateTime(2026, 11, 2, 10, 15));
      expect(kioskStatusLabel(paused, now: now), 'Tạm ngưng · nhận đơn lại lúc 10:15');
      const closed = Kiosk(id: 'a', name: 'A', open: false, waitMinutes: 0, openTime: '07:00');
      expect(kioskStatusLabel(closed, now: now), 'Đóng · mở lại 07:00');
      const closedNoHours = Kiosk(id: 'a', name: 'A', open: false, waitMinutes: 0);
      expect(kioskStatusLabel(closedNoHours, now: now), 'Đang đóng cửa');
    });
  });

  group('screen', () {
    for (final size in [TestScreens.narrow, TestScreens.wide]) {
      testWidgets('shows the search box, every kiosk and the confirm button at ${size.width.round()} dp', (
        tester,
      ) async {
        await pumpPicker(tester, KioskDeps(), size: size);
        for (final id in ['s27.search', 's27.kiosk.q9-t2', 's27.kiosk.q9-t4', 's27.kiosk.nvh-t1', 's27.confirm']) {
          expect(byId(id), findsOneWidget, reason: id);
        }
        expect(find.text('Mở · chờ 5–7 phút'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the chosen kiosk is marked as selected for screen readers', (tester) async {
      final vm = await pumpPicker(tester, KioskDeps());
      await tester.tap(byId('s27.kiosk.q9-t4'));
      await tester.pump();
      expect(vm.chosenId, 'q9-t4');
      expect(tester.getSemantics(find.bySemanticsIdentifier('s27.kiosk.q9-t4')), isSemantics(isSelected: true));
      expect(tester.getSemantics(find.bySemanticsIdentifier('s27.kiosk.q9-t2')), isSemantics(isSelected: false));
    });

    testWidgets('typing filters the list', (tester) async {
      await pumpPicker(tester, KioskDeps());
      await tester.enterText(find.byType(TextField), 'tầng 4');
      await tester.pump();
      expect(byId('s27.kiosk.q9-t4'), findsOneWidget);
      expect(byId('s27.kiosk.q9-t2'), findsNothing);
    });

    testWidgets('switching kiosk with a cart asks first; keeping the cart changes nothing', (tester) async {
      final deps = KioskDeps();
      await deps.cart.addItem('u1', kioskId: 'q9-t2', item: _item);
      await pumpPicker(tester, deps);
      await tester.tap(byId('s27.kiosk.q9-t4'));
      await tester.pump();
      await tester.tap(byId('s27.confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Đổi sang Kiosk Q9 · Tầng 4?'), findsOneWidget);
      await tester.tap(find.text('Giữ lại'));
      await tester.pumpAndSettle();
      expect(deps.session.selectedKioskId, 'q9-t2');
      expect((await deps.cart.watchCart('u1').first).isEmpty, isFalse);
    });

    testWidgets('a failed list offers a retry button', (tester) async {
      final deps = KioskDeps()..menu = _BrokenKiosks();
      await pumpPicker(tester, deps);
      expect(byId('s27.retry'), findsOneWidget);
    });
  });
}
