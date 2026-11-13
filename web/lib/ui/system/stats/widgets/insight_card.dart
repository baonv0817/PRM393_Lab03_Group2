import 'package:breakbite_admin/ui/system/stats/view_models/admin_stats_view_model.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// "Tóm tắt bằng AI" on the statistics page (docs/ai-feature.md, "Stats summary"): the admin asks, Gemini writes a
/// few lines about the period on screen. Nothing is sent until the button is pressed, and the text says it is
/// generated so nobody takes it for a figure. Hidden when `ai_enabled` is off in Remote Config.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key});

  static const label = 'Tóm tắt bằng AI';
  static const notice = 'Do AI viết từ các số liệu trên trang. Đối chiếu với biểu đồ trước khi dùng.';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminStatsViewModel>();
    if (!vm.insightAvailable) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final insight = vm.insight;
    final body = switch (insight) {
      null => Text('Nhờ AI nêu điều đáng chú ý của ${vm.days} ngày này.', style: text.bodyMedium),
      ViewLoading() => Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: AppSpacing.xs),
          Text('AI đang đọc số liệu…', style: text.bodyMedium),
        ],
      ),
      ViewError(:final message) => TestId(
        'a08.insight.error',
        child: Text(message, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
      ),
      ViewData(:final data) => TestId('a08.insight.text', child: SelectableText(data, style: text.bodyMedium)),
      ViewEmpty() => const SizedBox.shrink(),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: colors.primaryText),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(label, style: text.titleMedium)),
              TestId(
                'a08.insight.generate',
                child: AppButton(
                  label: insight == null ? 'Tạo tóm tắt' : 'Tạo lại',
                  icon: Icons.refresh,
                  variant: AppButtonVariant.secondary,
                  loading: insight is ViewLoading,
                  onPressed: vm.generateInsight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          body,
          if (insight is ViewData) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(notice, style: text.bodySmall?.copyWith(color: colors.muted)),
          ],
        ],
      ),
    );
  }
}
