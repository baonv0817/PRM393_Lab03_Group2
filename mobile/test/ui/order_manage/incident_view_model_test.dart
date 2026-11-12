import 'package:breakbite/ui/order_manage/view_models/incident_view_model.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

class _FailingOrders extends FakeOrderRepository {
  @override
  Stream<Order?> watchOrder(String id) => Stream.error(const NetworkException());
}

class _FailingIncidents extends FakeIncidentRepository {
  @override
  Stream<Incident?> watchOfOrder(String uid, String orderId) => Stream.error(const NetworkException());
}

class _NeverAnswers extends FakeIncidentRepository {
  @override
  Stream<Incident?> watchOfOrder(String uid, String orderId) => const Stream.empty();
}

class _Setup {
  _Setup({FakeOrderRepository? orders, FakeIncidentRepository? incidents})
    : orders = orders ?? FakeOrderRepository(),
      incidents = incidents ?? FakeIncidentRepository();

  final FakeOrderRepository orders;
  final FakeIncidentRepository incidents;
  final crash = FakeCrashService();

  IncidentViewModel viewModel(String orderId, {String uid = 'u1'}) => IncidentViewModel(
    orders: orders,
    incidents: incidents,
    crash: crash,
    uid: uid,
    customerName: 'Nguyễn Minh Quân',
    orderId: orderId,
  );

  /// A delivered order of 'u1'.
  Future<String> deliveredOrder() async {
    final id = await placeTestOrder(orders, uid: 'u1');
    await orders.accept(orders.all.single, readyIn: const Duration(minutes: 5));
    await orders.markReady(orders.all.single);
    await orders.deliver(orders.all.single);
    return id;
  }
}

void main() {
  group('IncidentViewModel', () {
    test('an order that was received opens the form, and says what is missing until it can be sent', () async {
      final setup = _Setup();
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();

      expect(vm.state, isA<ViewData<Order>>());
      expect(vm.incident, isNull);
      expect(vm.canSubmit, isFalse);
      expect(vm.missingHint, 'Chọn loại sự cố.');

      vm.selectType(IncidentType.missingItem);
      expect(vm.missingHint, 'Mô tả điều đã xảy ra để kiosk kiểm tra.');
      vm.setDescription('   ');
      expect(vm.canSubmit, isFalse);

      vm.setDescription('Thiếu 1 ly trà đào');
      expect(vm.canSubmit, isTrue);
      expect(vm.missingHint, isNull);
      vm.dispose();
    });

    test('the description stops at the maximum length and counts the characters left', () async {
      final setup = _Setup();
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();

      vm.setDescription('x' * 40);
      expect(vm.charactersLeft, IncidentViewModel.maxDescriptionLength - 40);
      vm.setDescription('y' * (IncidentViewModel.maxDescriptionLength + 30));
      expect(vm.description.length, IncidentViewModel.maxDescriptionLength);
      expect(vm.charactersLeft, 0);
      vm.dispose();
    });

    test('sending stores the report for this order and the screen switches to it', () async {
      final setup = _Setup();
      final id = await setup.deliveredOrder();
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      vm.selectType(IncidentType.wrongItem);
      vm.setDescription('  Em gọi trà đào nhưng nhận trà vải  ');
      final result = await vm.submit.execute();
      await pumpEventQueue();

      expect(result, isA<Ok<Incident>>());
      final stored = setup.incidents.all.single;
      expect(stored.orderId, id);
      expect(stored.uid, 'u1');
      expect(stored.kioskId, 'q9-t2');
      expect(stored.customerName, 'Nguyễn Minh Quân');
      expect(stored.type, IncidentType.wrongItem);
      expect(stored.description, 'Em gọi trà đào nhưng nhận trà vải');
      expect(stored.status, IncidentStatus.open);
      expect(vm.incident, isNotNull);
      expect(vm.typeLabel, 'Sai món');
      expect(vm.statusLabel, 'Đã gửi, chờ kiosk xem');
      expect(vm.sentAtLine, startsWith('Gửi lúc '));
      expect(vm.resolutionLine, isNull);
      vm.dispose();
    });

    test('sending without choosing a kind is refused with a message', () async {
      final setup = _Setup();
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();

      vm.setDescription('Thiếu món');
      final result = await vm.submit.execute();
      expect((result! as Err<Incident>).error.message, 'Chọn loại sự cố.');
      expect(setup.incidents.all, isEmpty);
      vm.dispose();
    });

    test('a failed send reports the reason, is recorded, keeps the form and can be tried again', () async {
      final setup = _Setup();
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();
      vm.selectType(IncidentType.quality);
      vm.setDescription('Món nguội');
      setup.incidents.failNextReport = const NetworkException();

      final failed = await vm.submit.execute();
      expect((failed! as Err<Incident>).error.message, const NetworkException().message);
      expect(setup.crash.errors, hasLength(1));
      expect(vm.incident, isNull);
      expect(vm.description, 'Món nguội');
      expect(vm.type, IncidentType.quality);

      final retry = await vm.submit.execute();
      await pumpEventQueue();
      expect(retry, isA<Ok<Incident>>());
      expect(vm.incident, isNotNull);
      vm.dispose();
    });

    test('an order has one report: a second one is refused and the screen already shows the first', () async {
      final setup = _Setup();
      final id = await setup.deliveredOrder();
      await setup.incidents.report(order: setup.orders.all.single, type: IncidentType.late, description: 'Lâu quá');
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      expect(vm.incident, isNotNull);
      expect(vm.typeLabel, 'Làm món quá lâu');
      final second = await setup.incidents.report(
        order: setup.orders.all.single,
        type: IncidentType.other,
        description: 'Lại nữa',
      );
      expect((second as Err<Incident>).error, isA<PermissionDeniedException>());
      expect(setup.incidents.all, hasLength(1));
      vm.dispose();
    });

    test('the kiosk handling follows live: being looked at, refunded, or rejected with a reason', () async {
      final setup = _Setup();
      final id = await setup.deliveredOrder();
      await setup.incidents.report(
        order: setup.orders.all.single,
        type: IncidentType.missingItem,
        description: 'Thiếu',
      );
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      setup.incidents.handle(id, status: IncidentStatus.inProgress);
      await pumpEventQueue();
      expect(vm.statusLabel, 'Kiosk đang xử lý');
      expect(vm.resolutionLine, isNull);

      setup.incidents.handle(
        id,
        status: IncidentStatus.resolved,
        resolution: IncidentResolution.refunded,
        refundVnd: 20000,
      );
      await pumpEventQueue();
      expect(vm.statusLabel, 'Đã xử lý');
      expect(vm.resolutionLine, 'Kiosk đồng ý hoàn 20.000đ cho bạn.');

      setup.incidents.handle(
        id,
        status: IncidentStatus.resolved,
        resolution: IncidentResolution.rejected,
        resolutionNote: 'Đã kiểm camera, đủ món',
      );
      await pumpEventQueue();
      expect(vm.resolutionLine, 'Kiosk không nhận báo cáo này: Đã kiểm camera, đủ món');

      setup.incidents.handle(id, status: IncidentStatus.resolved);
      await pumpEventQueue();
      expect(vm.resolutionLine, 'Kiosk đã xử lý báo cáo này.');
      vm.dispose();
    });

    test('an order that was not received yet cannot be reported, but an existing report still shows', () async {
      final setup = _Setup();
      final id = await placeTestOrder(setup.orders, uid: 'u1');
      final vm = setup.viewModel(id);
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<Order>>());
      expect((vm.state as ViewEmpty<Order>).message, IncidentViewModel.notDeliveredMessage);

      await setup.incidents.report(order: setup.orders.all.single, type: IncidentType.late, description: 'Lâu quá');
      await pumpEventQueue();
      expect(vm.state, isA<ViewData<Order>>());
      expect(vm.incident, isNotNull);
      vm.dispose();
    });

    test('an unknown order id is the empty state', () async {
      final vm = _Setup().viewModel('nope');
      await pumpEventQueue();

      expect(vm.state, isA<ViewEmpty<Order>>());
      expect((vm.state as ViewEmpty<Order>).message, IncidentViewModel.notFoundMessage);
      final result = await vm.submit.execute();
      expect((result! as Err<Incident>).error.message, IncidentViewModel.notFoundMessage);
      vm.dispose();
    });

    test('it stays loading until both the order and the report have arrived', () async {
      final setup = _Setup(incidents: _NeverAnswers());
      final vm = setup.viewModel(await setup.deliveredOrder());
      await pumpEventQueue();

      expect(vm.state, isA<ViewLoading<Order>>());
      vm.dispose();
    });

    test('a failed load, of the order or of the report, is an error that is recorded; retry loads again', () async {
      for (final setup in [_Setup(orders: _FailingOrders()), _Setup(incidents: _FailingIncidents())]) {
        final vm = setup.viewModel('A-204');
        await pumpEventQueue();

        expect(vm.state, isA<ViewError<Order>>());
        expect((vm.state as ViewError<Order>).message, const NetworkException().message);
        expect(setup.crash.errors, isNotEmpty);

        vm.load();
        expect(vm.state, isA<ViewLoading<Order>>());
        await pumpEventQueue();
        expect(vm.state, isA<ViewError<Order>>());
        vm.dispose();
      }
    });
  });
}
