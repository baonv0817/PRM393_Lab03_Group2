import 'package:breakbite/app.dart';
import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dev/fake_dependencies.dart';
import '../../dev/fakes/fakes.dart';
import '../helpers/orders.dart';

Future<AppDependencies> _open(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  final deps = createFakeDependencies(signedIn: true);
  await tester.pumpWidget(BreakBiteApp(dependencies: deps));
  await tester.pumpAndSettle();
  return deps;
}

AppNotification _push({String? orderId}) => AppNotification(
  id: 'n1',
  title: 'Món đã sẵn sàng',
  body: 'Mời bạn tới quầy nhận món.',
  receivedAt: DateTime(2026, 11, 7, 10),
  orderId: orderId,
);

void main() {
  testWidgets('T53: tapping a push about an order in the tray opens S07 for that order', (tester) async {
    final deps = await _open(tester);
    final id = await placeTestOrder(deps.orders as FakeOrderRepository, uid: 'dev-user');
    await tester.pumpAndSettle();

    (deps.messaging as FakeMessagingService).emitOpened(_push(orderId: id));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('s07.steps'), findsOneWidget);
  });

  testWidgets('T53: a push received in the foreground shows a banner; "Xem" opens the notification center', (
    tester,
  ) async {
    final deps = await _open(tester);
    (deps.messaging as FakeMessagingService).emitForeground(_push());
    await tester.pumpAndSettle();
    expect(find.text('Món đã sẵn sàng: Mời bạn tới quầy nhận món.'), findsOneWidget);

    await tester.tap(find.text('Xem'));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo'), findsWidgets);
    expect(find.byType(SnackBar), findsNothing);
  });
}
