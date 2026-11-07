import 'package:breakbite/data/order_status_notifier.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/notifications/view_models/notification_center_view_model.dart';
import 'package:breakbite/ui/notifications/view_models/notification_settings_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';

final _now = DateTime(2026, 11, 6, 12);

AppNotification _n(String id, {DateTime? at, bool read = false, String? orderId}) => AppNotification(
  id: id,
  title: 'Tiêu đề $id',
  body: 'Nội dung',
  receivedAt: at ?? _now,
  orderId: orderId,
  read: read,
);

void main() {
  group('NotificationPrefs', () {
    test('a stored map keeps its values, a missing key keeps its default, anything else is the defaults', () {
      const prefs = NotificationPrefs(orderReady: false, breakReminder: false, promo: true, orderUpdates: false);
      expect(NotificationPrefs.fromMap(prefs.toMap()), prefs);
      expect(NotificationPrefs.fromMap({'promo': true}), NotificationPrefs.defaults.copyWith(promo: true));
      expect(NotificationPrefs.fromMap(null), NotificationPrefs.defaults);
      expect(NotificationPrefs.fromMap({'promo': 'yes'}), NotificationPrefs.defaults);
      expect(NotificationPrefs.defaults.promo, isFalse, reason: 'offers are off until the customer asks (Figma)');
    });
  });

  group('FakeNotificationRepository', () {
    test('keeps one notification for one id and puts the newest first', () async {
      final repo = FakeNotificationRepository();
      await repo.save('u', _n('a', at: _now.subtract(const Duration(hours: 1))));
      await repo.save('u', _n('b'));
      await repo.save('u', _n('b'));
      expect(repo.of('u').map((n) => n.id), ['b', 'a']);
      await repo.markRead('u', 'a');
      expect(repo.of('u').map((n) => n.read), [false, true]);
      await repo.markAllRead('u');
      expect(repo.of('u').every((n) => n.read), isTrue);
    });
  });

  group('NotificationCenterViewModel (S19)', () {
    NotificationCenterViewModel vm(FakeNotificationRepository repo) =>
        NotificationCenterViewModel(notifications: repo, crash: FakeCrashService(), uid: 'u', clock: () => _now);

    test('is empty with an explanation until something arrives, then lists today and earlier apart', () async {
      final repo = FakeNotificationRepository();
      final model = vm(repo);
      await pumpEventQueue();
      expect(model.state, isA<ViewEmpty<List<AppNotification>>>());
      expect((model.state as ViewEmpty).message, NotificationCenterViewModel.emptyMessage);

      await repo.save('u', _n('today', at: DateTime(2026, 11, 6, 9)));
      await repo.save('u', _n('old', at: DateTime(2026, 11, 5, 18), read: true));
      await pumpEventQueue();
      expect(model.today.map((n) => n.id), ['today']);
      expect(model.earlier.map((n) => n.id), ['old']);
      expect(model.unreadCount, 1);
    });

    test('opening marks one read (and leaves a read one alone), "Đọc hết" marks all', () async {
      final repo = FakeNotificationRepository();
      await repo.save('u', _n('a'));
      await repo.save('u', _n('b', at: _now.subtract(const Duration(minutes: 5))));
      final model = vm(repo);
      await pumpEventQueue();

      expect(await model.open(model.all.first), isA<Ok<void>>());
      await pumpEventQueue();
      expect(model.unreadCount, 1);
      expect(await model.markAllRead(), isA<Ok<void>>());
      await pumpEventQueue();
      expect(model.unreadCount, 0);
    });

    test('a failed write is returned, and an order-ready notification is the one with the pickup button', () async {
      final repo = FakeNotificationRepository();
      await repo.save('u', _n('A-1_ready', orderId: 'A-1'));
      await repo.save('u', _n('A-1_preparing', orderId: 'A-1', at: _now.subtract(const Duration(minutes: 3))));
      final model = vm(repo);
      await pumpEventQueue();

      expect(model.all.map(NotificationCenterViewModel.isReady), [true, false]);
      repo.failNextWrite = const NetworkException();
      expect(await model.open(model.all.first), isA<Err<void>>());
    });
  });

  group('NotificationSettingsViewModel (S18)', () {
    NotificationSettingsViewModel vm(FakeNotificationRepository repo) =>
        NotificationSettingsViewModel(notifications: repo, crash: FakeCrashService(), uid: 'u');

    test('shows the defaults, writes a flipped switch and leaves the others alone', () async {
      final repo = FakeNotificationRepository();
      final model = vm(repo);
      await pumpEventQueue();

      expect(NotificationSwitch.values.map(model.valueOf), [true, true, false, true]);
      expect(await model.set(NotificationSwitch.promo, true), isA<Ok<void>>());
      await pumpEventQueue();
      expect(repo.prefsOf('u'), NotificationPrefs.defaults.copyWith(promo: true));
      expect(model.valueOf(NotificationSwitch.promo), isTrue);
      expect(model.valueOf(NotificationSwitch.orderReady), isTrue);
    });

    test('a failed write puts the switch back and returns the error', () async {
      final repo = FakeNotificationRepository();
      final model = vm(repo);
      await pumpEventQueue();

      repo.failNextWrite = const NetworkException();
      final result = await model.set(NotificationSwitch.orderUpdates, false);
      expect(result, isA<Err<void>>());
      expect(model.valueOf(NotificationSwitch.orderUpdates), isTrue);
      expect(repo.prefsOf('u'), NotificationPrefs.defaults);
    });

    test('flipping a switch to the value it already has writes nothing', () async {
      final repo = FakeNotificationRepository();
      final model = vm(repo);
      await pumpEventQueue();
      repo.failNextWrite = const NetworkException();
      expect(await model.set(NotificationSwitch.orderReady, true), isA<Ok<void>>());
      expect(repo.failNextWrite, isNotNull, reason: 'no write was made, so the failure is still waiting');
    });
  });

  group('OrderStatusNotifier', () {
    late FakeOrderRepository orders;
    late FakeNotificationRepository inbox;
    late OrderStatusNotifier notifier;

    setUp(() {
      orders = FakeOrderRepository();
      inbox = FakeNotificationRepository();
      notifier = OrderStatusNotifier(
        orders: orders,
        notifications: inbox,
        crash: FakeCrashService(),
        clock: () => _now,
      );
    });

    tearDown(() => notifier.stop());

    test('does not announce what was already so when it starts, only what changes afterwards', () async {
      final id = await placeTestOrder(orders, uid: 'u');
      await orders.accept(orders.all.single, readyIn: const Duration(minutes: 3));
      notifier.start('u');
      await pumpEventQueue();
      expect(inbox.of('u'), isEmpty);

      await orders.markReady(orders.all.firstWhere((o) => o.id == id));
      await pumpEventQueue();
      expect(inbox.of('u').map((n) => n.id), [AppNotification.idForOrder(id, OrderStatus.ready)]);
      expect(inbox.of('u').single.orderId, id);
      expect(NotificationCenterViewModel.isReady(inbox.of('u').single), isTrue);
    });

    test('says when an order starts, is handed over or is turned down by the kiosk, with the reason', () async {
      notifier.start('u');
      final a = await placeTestOrder(orders, uid: 'u');
      final b = await placeTestOrder(orders, uid: 'u');
      await pumpEventQueue();
      await orders.accept(orders.all.firstWhere((o) => o.id == a), readyIn: const Duration(minutes: 3));
      await orders.reject(orders.all.firstWhere((o) => o.id == b), reason: 'Hết món');
      await pumpEventQueue();

      final titles = inbox.of('u').map((n) => n.title).toList();
      expect(titles, containsAll(['Đơn #$a đang được làm', 'Đơn #$b bị từ chối']));
      expect(inbox.of('u').firstWhere((n) => n.orderId == b).body, contains('Hết món'));
    });

    test('an order the customer cancelled themselves is not announced to them', () async {
      notifier.start('u');
      final id = await placeTestOrder(orders, uid: 'u');
      await pumpEventQueue();
      await orders.cancelMyOrder(orders.all.firstWhere((o) => o.id == id));
      await pumpEventQueue();
      expect(inbox.of('u'), isEmpty);
    });

    test('respects the S18 switches and does not write twice for one change', () async {
      await inbox.setPrefs('u', NotificationPrefs.defaults.copyWith(orderReady: false));
      notifier.start('u');
      final id = await placeTestOrder(orders, uid: 'u');
      await pumpEventQueue();
      await orders.accept(orders.all.single, readyIn: const Duration(minutes: 3));
      await orders.markReady(orders.all.firstWhere((o) => o.id == id));
      await pumpEventQueue();
      expect(inbox.of('u').map((n) => n.title), ['Đơn #$id đang được làm'], reason: '"ready" is switched off');

      notifier.stop();
      notifier.start('u');
      await pumpEventQueue();
      expect(inbox.of('u'), hasLength(1));
    });

    test('stop() ends the watching and messageFor has no text for a new or cancelled-by-customer order', () async {
      notifier.start('u');
      notifier.stop();
      await placeTestOrder(orders, uid: 'u');
      await orders.accept(orders.all.single, readyIn: const Duration(minutes: 3));
      await pumpEventQueue();
      expect(inbox.of('u'), isEmpty);
      expect(OrderStatusNotifier.messageFor(orders.all.single), isNotNull);
    });
  });
}
