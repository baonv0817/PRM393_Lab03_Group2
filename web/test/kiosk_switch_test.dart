import 'package:breakbite_admin/ui/dashboard/widgets/dashboard_screen.dart';
import 'package:breakbite_admin/ui/review_queue/widgets/review_queue_screen.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/data/services/remote_config_service.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// Found on the deployed site (12/11/2026): an admin who picked another kiosk while "Duyệt đơn" was open kept
/// seeing the first kiosk's queue, because the screen's view model was not created again.
void main() {
  Future<(AdminSession, FakeOrderRepository)> pump(WidgetTester tester, Widget screen) async {
    final auth = FakeAuthService(nextUser: admin);
    final menu = FakeMenuRepository();
    final orders = FakeOrderRepository();
    final session = AdminSession(auth: auth, menu: menu);
    // As in the app, the shell only shows a screen once the session has a kiosk.
    auth.emit(admin);
    await tester.pump();
    menu.kiosks.add(const [
      Kiosk(id: 'q9-t2', name: 'Kiosk Q9 · Tầng 2', open: true, waitMinutes: 5),
      Kiosk(id: 'nvh-t1', name: 'Nhà văn hóa SV · Tầng 1', open: true, waitMinutes: 5),
    ]);
    await tester.pump();
    expect(session.kioskId, 'q9-t2');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OrderRepository>.value(value: orders),
          Provider<MenuRepository>.value(value: menu),
          Provider<AnalyticsService>.value(value: FakeAnalytics()),
          Provider<RemoteConfigService>.value(value: FakeRemoteConfig()),
          ChangeNotifierProvider<AdminSession>.value(value: session),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pump();
    return (session, orders);
  }

  testWidgets('W03: picking another kiosk makes the open review queue listen to that kiosk', (tester) async {
    final (session, orders) = await pump(tester, const ReviewQueueScreen());
    expect(orders.watchedKiosks.last, 'q9-t2');
    session.selectKiosk('nvh-t1');
    await tester.pump();
    expect(orders.watchedKiosks.last, 'nvh-t1');
  });

  testWidgets('W04: picking another kiosk recomputes the open dashboard for that kiosk', (tester) async {
    final (session, orders) = await pump(tester, const DashboardScreen());
    await tester.pump();
    final firstSince = orders.statsSince;
    expect(firstSince, isNotNull);
    orders.statsSince = null;
    session.selectKiosk('nvh-t1');
    await tester.pump();
    await tester.pump();
    expect(orders.statsSince, isNotNull, reason: 'a new dashboard view model asked for the new kiosk');
  });
}
