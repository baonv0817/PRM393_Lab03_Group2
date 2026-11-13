import 'package:breakbite_admin/ui/system/stats/view_models/admin_stats_view_model.dart';
import 'package:breakbite_admin/ui/system/stats/widgets/insight_card.dart';
import 'package:breakbite_core/data/services/remote_config_service.dart';
import 'package:breakbite_core/data/services/stats_insight_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/stats_digest.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart' as web;
import 'fake_menu_repository.dart';
import 'fakes/system_fakes.dart';

final _now = DateTime.utc(2026, 11, 11, 5);

class _FakeInsight implements StatsInsightService {
  Result<String> answer = const Result.ok('- Doanh thu ổn định.');
  final calls = <({String digest, String model, String prompt})>[];

  @override
  Future<Result<String>> summarize(String digest, {required String model, required String prompt}) async {
    calls.add((digest: digest, model: model, prompt: prompt));
    return answer;
  }
}

void main() {
  group('statsDigest', () {
    test('has the totals, the change against the period before and the best sellers, and no customer data', () async {
      final repo = FakeAdminOrderRepository(now: _now);
      final vm = AdminStatsViewModel(orders: repo, menu: FakeMenuRepository(), clock: () => _now);
      await pumpEventQueue();
      final text = statsDigest(report: vm.state.dataOrNull!, previous: vm.previous, days: 7);
      expect(text, contains('Phạm vi: mọi kiosk, 7 ngày gần nhất.'));
      expect(text, contains('Số đơn: 7'));
      expect(text, contains('Doanh thu: 160000 đồng'));
      expect(text, isNot(contains('Khách')));
      vm.dispose();
    });
  });

  group('AdminStatsViewModel AI summary', () {
    late _FakeInsight ai;
    late web.FakeRemoteConfig config;
    late web.FakeAnalytics analytics;

    AdminStatsViewModel makeVm({bool enabled = true, bool withService = true}) {
      config = web.FakeRemoteConfig({RemoteKeys.aiEnabled: enabled});
      return AdminStatsViewModel(
        orders: FakeAdminOrderRepository(now: _now),
        menu: FakeMenuRepository(),
        insightService: withService ? ai : null,
        remoteConfig: config,
        analytics: analytics,
        clock: () => _now,
      );
    }

    setUp(() {
      ai = _FakeInsight();
      analytics = web.FakeAnalytics();
    });

    test('is not offered when Remote Config has the AI off, or the build has no service', () async {
      final off = makeVm(enabled: false);
      expect(off.insightAvailable, isFalse);
      off.dispose();
      final none = makeVm(withService: false);
      expect(none.insightAvailable, isFalse);
      none.dispose();
    });

    test('nothing is sent until the admin asks; then the digest, model and prompt go to the service', () async {
      final vm = makeVm();
      await pumpEventQueue();
      expect(ai.calls, isEmpty);
      expect(vm.insight, isNull);
      await vm.generateInsight();
      expect(ai.calls, hasLength(1));
      expect(ai.calls.single.digest, contains('Số đơn: 7'));
      expect(ai.calls.single.model, RemoteKeys.defaultAiModel);
      expect(ai.calls.single.prompt, RemoteKeys.defaultAiInsightPrompt);
      expect((vm.insight as ViewData<String>).data, '- Doanh thu ổn định.');
      expect(analytics.paramsOf('ai_request').single!['feature'], AdminStatsViewModel.insightFeature);
      vm.dispose();
    });

    test('a failure shows its message, logs ai_error, and leaves the figures alone', () async {
      ai.answer = Result.error(AiException.insight(AiFailure.quota));
      final vm = makeVm();
      await pumpEventQueue();
      await vm.generateInsight();
      expect(vm.insight, isA<ViewError<String>>());
      expect((vm.insight as ViewError<String>).message, contains('quá tải'));
      expect(analytics.paramsOf('ai_error').single!['reason'], 'quota');
      expect(vm.state.dataOrNull, isNotNull);
      vm.dispose();
    });

    test('changing the period or the kiosk clears the text, which described the old figures', () async {
      final vm = makeVm();
      await pumpEventQueue();
      await vm.generateInsight();
      expect(vm.insight, isNotNull);
      vm.setDays(14);
      expect(vm.insight, isNull);
      vm.dispose();
    });

    test('when Remote Config turns the AI off meanwhile, asking gives the "off" message and calls nothing', () async {
      final vm = makeVm();
      await pumpEventQueue();
      config.values[RemoteKeys.aiEnabled] = false;
      await vm.generateInsight();
      expect(ai.calls, isEmpty);
      expect((vm.insight as ViewError<String>).message, contains('đang tắt'));
      vm.dispose();
    });
  });

  test('the card names itself and says the text comes from AI', () {
    expect(InsightCard.label, 'Tóm tắt bằng AI');
    expect(InsightCard.notice, contains('AI'));
  });
}
