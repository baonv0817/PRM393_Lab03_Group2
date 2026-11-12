import 'package:breakbite/ui/profile/view_models/firebase_demo_view_model.dart';
import 'package:breakbite/ui/profile/widgets/firebase_demo_screen.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/test_id.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../dev/fakes/fakes.dart';
import '../../helpers/orders.dart';
import '../../helpers/pump.dart';

class _FailingStorage extends FakeStorageService {
  @override
  Future<Result<UploadedFile>> upload({
    required UploadFolder folder,
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    return const Result.error(NetworkException());
  }
}

class DemoDeps {
  final remoteConfig = FakeRemoteConfigService();
  final crash = FakeCrashService();
  final analytics = FakeAnalyticsService();
  FakeStorageService storage = FakeStorageService();
  final reportFiles = FakeReportFileService();
  final reports = FakeReportRepository();
  final orders = FakeOrderRepository();

  FirebaseDemoViewModel build({String uid = 'u1'}) => FirebaseDemoViewModel(
    remoteConfig: remoteConfig,
    crash: crash,
    analytics: analytics,
    storage: storage,
    reportFiles: reportFiles,
    reports: reports,
    orders: orders,
    uid: uid,
    customerName: 'Nguyễn Minh Quân',
    clock: () => DateTime(2026, 11, 2, 10, 20),
  );
}

Finder byId(String id) => find.byWidgetPredicate((w) => w is TestId && w.id == id);

/// Scrolls until the widget is built, then brings all of it on screen: `scrollUntilVisible` stops as soon as the
/// widget peeks in at the bottom edge, where a tap on its centre would miss (the Remote Config list grew with the
/// three AI keys of the final assignment).
Future<void> scrollTo(WidgetTester tester, String id) async {
  await tester.scrollUntilVisible(byId(id), 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(byId(id));
  await tester.pumpAndSettle();
}

Future<FirebaseDemoViewModel> pumpDemo(WidgetTester tester, DemoDeps deps, {Size size = TestScreens.narrow}) async {
  final demo = deps.build();
  addTearDown(demo.dispose);
  await pumpScreen(
    tester,
    const FirebaseDemoScreen(),
    providers: [ChangeNotifierProvider<FirebaseDemoViewModel>.value(value: demo)],
    size: size,
  );
  return demo;
}

void main() {
  group('Remote Config', () {
    test('shows every key with its value and where it came from', () async {
      final deps = DemoDeps();
      final demo = deps.build();
      expect(demo.config.map((e) => e.key), RemoteKeys.defaults.keys);
      expect(demo.config.every((e) => e.source == RemoteValueSource.inApp), isTrue);
      expect(demo.configFetchedAt, isNull);
      demo.dispose();
    });

    test('a value published on the console shows at once, marked as coming from the console', () async {
      final deps = DemoDeps();
      final demo = deps.build();
      deps.remoteConfig.publish(RemoteKeys.quickItemsLimit, 2);
      await pumpEventQueue();
      final entry = demo.config.firstWhere((e) => e.key == RemoteKeys.quickItemsLimit);
      expect(entry.value, 2);
      expect(entry.source, RemoteValueSource.console);
      expect(demo.configFetchedAt, isNotNull);
      demo.dispose();
    });

    test('refreshing fetches and reads the values again', () async {
      final deps = DemoDeps();
      final demo = deps.build();
      await demo.refreshConfig.execute();
      expect(deps.remoteConfig.fetches, 1);
      expect(demo.configFetchedAt, isNotNull);
      demo.dispose();
    });
  });

  group('Crashlytics', () {
    test('the test error is recorded as a non-fatal error with a reason', () async {
      final deps = DemoDeps();
      final demo = deps.build();
      await demo.recordTestError.execute();
      expect(deps.crash.errors.single, isA<StateError>());
      demo.dispose();
    });

    test('the test crash goes straight to the crash service', () {
      final deps = DemoDeps();
      final demo = deps.build();
      expect(demo.crashForTest, throwsStateError);
      demo.dispose();
    });
  });

  group('export and upload', () {
    test('makes a PDF of my orders, uploads it under my folder and saves its metadata', () async {
      final deps = DemoDeps();
      await placeTestOrder(deps.orders, uid: 'u1');
      await placeTestOrder(deps.orders, uid: 'someone-else');
      final demo = deps.build();
      final progress = <double>[];
      demo.addListener(() => progress.add(demo.uploadProgress));

      final result = await demo.exportAndUpload.execute();

      final report = (result! as Ok<Report>).value;
      expect(deps.reportFiles.exported.single.map((o) => o.uid), ['u1']);
      expect(deps.storage.uploads.single.publicId, startsWith('breakbite/reports/u1/'));
      expect(report.uid, 'u1');
      expect(report.url, startsWith('https://'));
      expect(demo.lastReport, report);
      expect(demo.stage, ExportStage.idle);
      expect(progress, containsAllInOrder([0.25, 0.5, 0.75, 1.0]));
      expect(deps.analytics.events.single.name, AnalyticsEvents.exportReport);
      await pumpEventQueue();
      expect(demo.myReports.dataOrNull, [report]);
      demo.dispose();
    });

    test('an upload error comes back as a message, records the error and saves nothing', () async {
      final deps = DemoDeps()..storage = _FailingStorage();
      final demo = deps.build();
      final result = await demo.exportAndUpload.execute();
      expect((result! as Err<Report>).error, isA<NetworkException>());
      expect(deps.crash.errors, hasLength(1));
      expect(deps.reports.all, isEmpty);
      expect(demo.stage, ExportStage.idle);
      expect(deps.analytics.events, isEmpty);
      demo.dispose();
    });

    test('a PDF that cannot be made uploads nothing', () async {
      final deps = DemoDeps();
      deps.reportFiles.fail = true;
      final demo = deps.build();
      final result = await demo.exportAndUpload.execute();
      expect((result! as Err<Report>).error.message, 'Không tạo được tệp PDF.');
      expect(deps.storage.uploads, isEmpty);
      demo.dispose();
    });

    test('a signed-out user cannot export', () async {
      final deps = DemoDeps();
      final demo = deps.build(uid: '');
      final result = await demo.exportAndUpload.execute();
      expect((result! as Err<Report>).error, isA<PermissionDeniedException>());
      demo.dispose();
    });

    test('my files start empty and list only my reports', () async {
      final deps = DemoDeps();
      final demo = deps.build();
      await pumpEventQueue();
      expect(demo.myReports, isA<ViewEmpty<List<Report>>>());
      await deps.reports.save(
        uid: 'someone-else',
        fileName: 'x.pdf',
        file: const UploadedFile(url: 'https://x', publicId: 'x', sizeBytes: 2048),
      );
      await pumpEventQueue();
      expect(demo.myReports, isA<ViewEmpty<List<Report>>>());
      demo.dispose();
    });
  });

  group('screen', () {
    for (final size in [TestScreens.narrow, TestScreens.wide]) {
      testWidgets('shows every part of the demo area at ${size.width.round()} dp without overflow', (tester) async {
        await pumpDemo(tester, DemoDeps(), size: size);
        for (final id in [
          'demo.notifications',
          'demo.config.${RemoteKeys.quickItemsLimit.replaceAll('_', '-')}',
          'demo.config.${RemoteKeys.promoBannerEnabled.replaceAll('_', '-')}',
          'demo.config.${RemoteKeys.pickupSlotEnabled.replaceAll('_', '-')}',
          'demo.config.refresh',
          'demo.crash.error',
          'demo.crash.crash',
          'demo.export',
        ]) {
          await scrollTo(tester, id);
          expect(byId(id), findsOneWidget, reason: id);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a console change shows on screen without reopening it', (tester) async {
      final deps = DemoDeps();
      await pumpDemo(tester, deps);
      expect(find.text('5'), findsOneWidget);
      deps.remoteConfig.publish(RemoteKeys.quickItemsLimit, 3);
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('từ console'), findsOneWidget);
    });

    testWidgets('export shows the uploaded file with its link and lists it under my files', (tester) async {
      final deps = DemoDeps();
      await pumpDemo(tester, deps);
      await scrollTo(tester, 'demo.export');
      await tester.tap(byId('demo.export'));
      await tester.pumpAndSettle();
      expect(find.text('Đã tải tệp lên.'), findsOneWidget);
      await scrollTo(tester, 'demo.export.url');
      expect(find.textContaining('https://files.invalid/breakbite/reports/u1/'), findsOneWidget);
      await scrollTo(tester, 'demo.reports.0');
      expect(byId('demo.reports.0'), findsOneWidget);
    });

    testWidgets('the test crash asks for confirmation; cancelling crashes nothing', (tester) async {
      final deps = DemoDeps();
      await pumpDemo(tester, deps);
      await scrollTo(tester, 'demo.crash.crash');
      await tester.tap(byId('demo.crash.crash'));
      await tester.pumpAndSettle();
      expect(find.text('Làm sập app thử?'), findsOneWidget);
      await tester.tap(find.text('Giữ lại'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('recording a test error confirms it with a message', (tester) async {
      final deps = DemoDeps();
      await pumpDemo(tester, deps);
      await scrollTo(tester, 'demo.crash.error');
      await tester.tap(byId('demo.crash.error'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã ghi một lỗi thử'), findsOneWidget);
      expect(deps.crash.errors, hasLength(1));
    });
  });
}
