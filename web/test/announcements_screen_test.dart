import 'package:breakbite_admin/ui/announcements/widgets/announcements_screen.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_core/data/repositories/announcement_repository.dart';
import 'package:breakbite_core/data/services/analytics_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// CR-F02: "Đăng" and "Lưu trữ" on W05 say how it went, instead of failing silently.
void main() {
  Future<FakeAnnouncementRepository> pump(WidgetTester tester) async {
    final auth = FakeAuthService(nextUser: admin);
    final repo = FakeAnnouncementRepository();
    final session = AdminSession(auth: auth, menu: FakeMenuRepository());
    auth.emit(admin);
    await tester.pump();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AnnouncementRepository>.value(value: repo),
          Provider<AnalyticsService>.value(value: FakeAnalytics()),
          ChangeNotifierProvider<AdminSession>.value(value: session),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: AnnouncementsScreen()),
        ),
      ),
    );
    repo.all.add([
      Announcement(
        id: 'a1',
        title: 'Khai trương',
        body: 'Giảm 10%',
        status: AnnouncementStatus.published,
        createdBy: 'a1',
        publishedAt: DateTime(2026, 11, 12, 23, 59),
      ),
    ]);
    await tester.pump();
    return repo;
  }

  testWidgets('archiving says it worked', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Lưu trữ'));
    await tester.pump();
    await tester.pump();
    expect(repo.statuses.single, ('a1', AnnouncementStatus.archived));
    expect(find.text('Đã lưu trữ. Khách không còn thấy thông báo này.'), findsOneWidget);
  });

  testWidgets('a failed archive shows why instead of nothing', (tester) async {
    final repo = await pump(tester);
    repo.failStatus = const PermissionDeniedException(message: 'Chỉ quản trị viên được sửa thông báo.');
    await tester.tap(find.text('Lưu trữ'));
    await tester.pump();
    await tester.pump();
    expect(repo.statuses, isEmpty);
    expect(find.text('Chỉ quản trị viên được sửa thông báo.'), findsOneWidget);
  });
}
