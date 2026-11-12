import 'package:breakbite/routing/push_router.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fakes/fakes.dart';

const _customer = AppUser(uid: 'u1', displayName: 'An', role: UserRole.user);
const _staff = AppUser(uid: 's1', displayName: 'Bếp', role: UserRole.staff, kioskId: 'q9-t2');

AppNotification _push({String? orderId}) => AppNotification(
  id: 'n1',
  title: 'Món đã sẵn sàng',
  body: 'Đơn #A-204 đang chờ bạn ở quầy.',
  receivedAt: DateTime(2026, 11, 7, 10),
  orderId: orderId,
);

void main() {
  late FakeMessagingService messaging;
  late List<String> opened;
  late List<AppNotification> banners;
  late void Function() lastBannerOpen;
  AppUser? user;

  PushRouter build() => PushRouter(
    messaging: messaging,
    crash: FakeCrashService(),
    currentUser: () => user,
    go: opened.add,
    showBanner: (n, open) {
      banners.add(n);
      lastBannerOpen = open;
    },
  )..start();

  setUp(() {
    messaging = FakeMessagingService();
    opened = [];
    banners = [];
    user = _customer;
  });

  test('a notification about an order opens that order, any other opens the notification center', () {
    expect(PushRouter.routeFor(_push(orderId: 'A-204')), AppRoutes.orderOf('A-204'));
    expect(PushRouter.routeFor(_push()), AppRoutes.notifications);
    expect(PushRouter.routeFor(_push(orderId: '')), AppRoutes.notifications);
  });

  test('tapping a notification in the tray opens its screen', () async {
    final router = build();
    messaging.emitOpened(_push(orderId: 'A-204'));
    await pumpEventQueue();
    expect(opened, ['/orders/A-204']);
    router.stop();
  });

  test('a tap that started the app waits for the sign-in, then opens the screen once', () async {
    user = null;
    final router = build();
    messaging.emitOpened(_push(orderId: 'A-204'));
    await pumpEventQueue();
    expect(opened, isEmpty);
    expect(router.pending, '/orders/A-204');

    user = _customer;
    router
      ..onUserChanged()
      ..onUserChanged();
    expect(opened, ['/orders/A-204']);
    expect(router.pending, isNull);
    router.stop();
  });

  test('staff accounts are not sent to customer screens', () async {
    user = _staff;
    final router = build();
    messaging
      ..emitOpened(_push(orderId: 'A-204'))
      ..emitForeground(_push(orderId: 'A-204'));
    await pumpEventQueue();
    expect(opened, isEmpty);
    expect(banners, isEmpty);
    router.stop();
  });

  test('a notification received while the app is open shows a banner whose action opens the screen', () async {
    final router = build();
    messaging.emitForeground(_push());
    await pumpEventQueue();
    expect(banners.single.title, 'Món đã sẵn sàng');
    expect(opened, isEmpty);
    lastBannerOpen();
    expect(opened, [AppRoutes.notifications]);
    router.stop();
  });

  test('after stop nothing is opened any more', () async {
    build().stop();
    messaging.emitOpened(_push(orderId: 'A-204'));
    await pumpEventQueue();
    expect(opened, isEmpty);
  });
}
