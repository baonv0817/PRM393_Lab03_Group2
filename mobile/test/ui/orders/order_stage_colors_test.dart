import 'package:breakbite/ui/orders/view_models/order_tracking_view_model.dart';
import 'package:breakbite/ui/orders/widgets/order_tracking_screen.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/order_stage.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';
import '../../helpers/pump.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

/// The colour of the banner box that says what is happening now (its border).
Color _bannerBorder(WidgetTester tester) {
  final box = tester.widget<Container>(find.descendant(of: byId('s07.banner'), matching: find.byType(Container)).first);
  return ((box.decoration! as BoxDecoration).border! as Border).top.color;
}

Future<(FakeOrderRepository, Order)> _open(WidgetTester tester) async {
  final orders = FakeOrderRepository();
  final id = await placeTestOrder(orders, uid: 'u1');
  final vm = OrderTrackingViewModel(
    orders: orders,
    menu: FakeMenuRepository(),
    crash: FakeCrashService(),
    orderId: id,
    clock: () => DateTime.now(),
  );
  addTearDown(vm.dispose);
  await pumpScreen(tester, const OrderTrackingScreen(), providers: [ChangeNotifierProvider.value(value: vm)]);
  return (orders, vm.order!);
}

void main() {
  testWidgets('S07 changes colour with each stage: waiting, being made, ready, picked up', (tester) async {
    final (orders, order) = await _open(tester);
    expect(_bannerBorder(tester), OrderStage.pending.color);

    await orders.accept(order, readyIn: const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(_bannerBorder(tester), OrderStage.preparing.color);

    final accepted = (await orders.watchOrder(order.id).first)!;
    await orders.markReady(accepted);
    await tester.pumpAndSettle();
    expect(_bannerBorder(tester), OrderStage.ready.color);

    final ready = (await orders.watchOrder(order.id).first)!;
    await orders.deliver(ready);
    await tester.pumpAndSettle();
    expect(_bannerBorder(tester), OrderStage.delivered.color);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S07 shows a cancelled order in red, with its reason', (tester) async {
    final (orders, order) = await _open(tester);
    await orders.reject(order, reason: 'Hết nguyên liệu');
    await tester.pumpAndSettle();
    expect(_bannerBorder(tester), OrderStage.cancelled.color);
    expect(find.textContaining('Hết nguyên liệu'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
  });

  testWidgets('the badge and the steps carry the stage colour and an icon, not the colour alone', (tester) async {
    final (orders, order) = await _open(tester);
    await orders.accept(order, readyIn: const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(find.byIcon(OrderStage.preparing.icon), findsWidgets, reason: 'the badge and the current step');
    final badge = tester.widget<StatusBadge>(find.byType(StatusBadge));
    expect(badge.stage, OrderStage.preparing);
  });
}
