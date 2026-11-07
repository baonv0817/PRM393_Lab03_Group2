import 'package:breakbite/app.dart';
import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fake_dependencies.dart';
import '../../dev/fakes/fakes.dart';
import '../helpers/orders.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

Future<AppDependencies> openSignedIn(WidgetTester tester, {Size size = const Size(412, 915)}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final deps = createFakeDependencies(signedIn: true);
  await tester.pumpWidget(BreakBiteApp(dependencies: deps));
  await tester.pumpAndSettle();
  return deps;
}

Future<void> tapId(WidgetTester tester, String id) async {
  if (byId(id).evaluate().isEmpty) {
    await tester.scrollUntilVisible(byId(id), 120, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(byId(id));
  await tester.pumpAndSettle();
  await tester.tap(byId(id));
  await tester.pumpAndSettle();
}

Order _order(AppDependencies deps, String id) => (deps.orders as FakeOrderRepository).all.firstWhere((o) => o.id == id);

void main() {
  for (final size in const [Size(360, 800), Size(412, 915)]) {
    testWidgets('F6 at ${size.width.round()} dp: S04 heart → S13 → add to cart → remove the heart', (tester) async {
      final deps = await openSignedIn(tester, size: size);
      final favorites = deps.favorites as FakeFavoriteRepository;

      await tester.tap(find.text('Thực đơn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combo Tacos Bò Phô Mai'));
      await tester.pumpAndSettle();
      await tapId(tester, 's04.favorite');
      expect(favorites.of('dev-user').map((f) => f.dishId), ['tacos-bo']);
      expect(find.byTooltip('Bỏ khỏi món yêu thích'), findsOneWidget, reason: 'the heart is filled now');
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      await tapId(tester, 's15.favorites');
      expect(find.text('Món yêu thích'), findsWidgets);
      expect(byId('s13.item.tacos-bo'), findsOneWidget);
      expect(find.text('39.000đ'), findsOneWidget);

      await tapId(tester, 's13.item.tacos-bo.add');
      expect((deps.cart as FakeCartRepository).current('dev-user').items.single.itemId, 'm1');
      await tapId(tester, 's13.remove.tacos-bo');
      expect(favorites.of('dev-user'), isEmpty);
      expect(byId('s13.empty'), findsOneWidget);
    });
  }

  testWidgets('F8: the kiosk makes the order ready → bell shows a dot → S19 → "Xem mã nhận món" opens S20', (
    tester,
  ) async {
    final deps = await openSignedIn(tester);
    final orders = deps.orders as FakeOrderRepository;
    final id = await placeTestOrder(orders, uid: 'dev-user');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Thông báo'), findsOneWidget, reason: 'nothing new yet');

    await orders.accept(_order(deps, id), readyIn: const Duration(minutes: 3));
    await orders.markReady(_order(deps, id));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Thông báo, 2 chưa đọc'), findsOneWidget);

    await tapId(tester, 's02.notifications');
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Đơn #$id đã sẵn sàng'), findsOneWidget);
    expect(find.text('Đơn #$id đang được làm'), findsOneWidget);
    await tapId(tester, 's19.code.$id-ready');

    expect(byId('s20.card'), findsOneWidget);
    final inbox = (deps.notifications as FakeNotificationRepository).of('dev-user');
    expect(inbox.firstWhere((n) => n.id.endsWith('_ready')).read, isTrue, reason: 'opening marks it read');
    expect(inbox.firstWhere((n) => n.id.endsWith('_preparing')).read, isFalse);
  });

  testWidgets('S19 "Đọc hết" marks every notification read and the button goes away', (tester) async {
    final deps = await openSignedIn(tester);
    final inbox = deps.notifications as FakeNotificationRepository;
    final now = DateTime.now();
    await inbox.save('dev-user', AppNotification(id: 'a', title: 'Tin A', body: 'x', receivedAt: now));
    await inbox.save(
      'dev-user',
      AppNotification(id: 'b', title: 'Tin B', body: 'y', receivedAt: now.subtract(const Duration(days: 2))),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Thông báo, 2 chưa đọc'), findsOneWidget);

    await tapId(tester, 's02.notifications');
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Trước đó'), findsOneWidget);
    await tapId(tester, 's19.readAll');
    expect(inbox.of('dev-user').every((n) => n.read), isTrue);
    expect(byId('s19.readAll'), findsNothing);
    expect(find.textContaining('Đã xem'), findsNWidgets(2));
  });

  testWidgets('S19 empty: a new customer sees why there is nothing, and S18 saves a switch as it is flipped', (
    tester,
  ) async {
    final deps = await openSignedIn(tester);
    await tapId(tester, 's02.notifications');
    expect(byId('s19.empty'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tapId(tester, 's15.notifications');
    expect(find.text('Cài đặt thông báo'), findsWidgets);
    expect(find.text('Khuyến mãi'), findsOneWidget);
    final repo = deps.notifications as FakeNotificationRepository;
    expect(repo.prefsOf('dev-user').promo, isFalse);

    await tapId(tester, 's18.promo');
    expect(repo.prefsOf('dev-user').promo, isTrue);
    await tapId(tester, 's18.orderReady');
    expect(repo.prefsOf('dev-user'), NotificationPrefs.defaults.copyWith(promo: true, orderReady: false));
    repo.failNextWrite = null;
  });

  testWidgets(
    'F11 search: Home → S28, a result goes in the cart, a word with no match shows S28-EMPTY and suggestions',
    (tester) async {
      final deps = await openSignedIn(tester);
      await tapId(tester, 's02.search');
      expect(byId('s28.hint'), findsOneWidget);
      final field = tester.widget<TextField>(find.descendant(of: byId('s28.search'), matching: find.byType(TextField)));
      expect(field.focusNode?.hasFocus, isTrue, reason: 'the cursor is already in the search box');

      await tester.enterText(find.descendant(of: byId('s28.search'), matching: find.byType(TextField)), 'tra dao');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('1 kết quả cho "tra dao"'), findsOneWidget);
      await tapId(tester, 's28.item.m3.add');
      expect((deps.cart as FakeCartRepository).current('dev-user').items.single.itemId, 'm3');

      await tester.enterText(find.descendant(of: byId('s28.search'), matching: find.byType(TextField)), 'bánh mì');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(byId('s28.empty'), findsOneWidget);
      expect(find.text('Không tìm thấy "bánh mì"'), findsOneWidget);
      await tapId(tester, 's28.suggest.tacos');
      expect(find.text('2 kết quả cho "Tacos"'), findsOneWidget);
      expect((deps.analytics as FakeAnalyticsService).events.where((e) => e.name == 'search'), hasLength(3));
    },
  );

  testWidgets('F6 reorder: Home → S14 sheet → pick an older order → the cart opens with its dishes', (tester) async {
    final deps = await openSignedIn(tester);
    final orders = deps.orders as FakeOrderRepository;
    await placeTestOrder(
      orders,
      uid: 'dev-user',
      items: const [CartItem(itemId: 'm1', name: 'Combo Tacos', priceVnd: 39000)],
    );
    await placeTestOrder(
      orders,
      uid: 'dev-user',
      items: const [CartItem(itemId: 'm3', name: 'Trà Đào', priceVnd: 20000)],
    );
    await tester.pumpAndSettle();

    await tapId(tester, 's02.reorderMore');
    expect(find.text('Đặt lại đơn gần đây'), findsWidgets);
    expect(find.text('Thêm vào giỏ · 20.000đ'), findsOneWidget, reason: 'the newest order is chosen first');
    await tapId(tester, 's14.order.A-204');
    expect(find.text('Thêm vào giỏ · 39.000đ'), findsOneWidget);
    await tapId(tester, 's14.add');

    expect((deps.cart as FakeCartRepository).current('dev-user').items.map((i) => i.itemId), ['m1']);
    expect(byId('s05.checkout'), findsOneWidget, reason: 'the cart (S05) opened');
  });

  testWidgets('S14 empty: a customer without orders has no reorder card, so S14 is not offered', (tester) async {
    await openSignedIn(tester);
    expect(byId('s02.reorderMore'), findsNothing);
  });

  testWidgets('S30: offline covers the app, "Thử lại" keeps it while offline, "Xem giỏ hàng" opens the cart', (
    tester,
  ) async {
    final deps = await openSignedIn(tester);
    final network = deps.connectivity as FakeConnectivityService;
    await tapId(tester, 's02.item.m1.add');

    network.online = false;
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối mạng'), findsOneWidget);
    await tapId(tester, 's30.retry');
    expect(find.text('Mất kết nối mạng'), findsOneWidget, reason: 'still offline');

    await tapId(tester, 's30.cart');
    expect(find.text('Mất kết nối mạng'), findsNothing);
    expect(byId('s05.checkout'), findsOneWidget);

    network.online = true;
    await tester.pumpAndSettle();
    network.online = false;
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối mạng'), findsOneWidget);
    network.online = true;
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối mạng'), findsNothing);
  });
}
