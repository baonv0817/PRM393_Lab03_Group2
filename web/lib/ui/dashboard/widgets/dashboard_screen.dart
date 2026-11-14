import 'package:breakbite_admin/ui/dashboard/view_models/dashboard_view_model.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/domain/models/kiosk_stats.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/inputs.dart';
import 'package:breakbite_core/ui/core/widgets/state_views.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// W04 Dashboard: five figures from aggregation queries and a chart of orders per hour.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The admin's kiosk picker changes the kiosk while this screen stays open: a new kiosk gets a new view model
    // (the key), so the screen never keeps listening to the previous kiosk.
    final kioskId = context.select<AdminSession, String?>((s) => s.kioskId)!;
    return ChangeNotifierProvider(
      key: ValueKey(kioskId),
      create: (context) => DashboardViewModel(orders: context.read<OrderRepository>(), kioskId: kioskId),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    return AdminPage(
      title: 'Thống kê',
      subtitle: 'Số liệu của quầy từ ngày ${formatDate(vm.since)} đến nay.',
      actions: [
        AppChip(
          label: 'Hôm nay',
          selected: vm.period == DashboardPeriod.today,
          onSelected: (_) => vm.setPeriod(DashboardPeriod.today),
        ),
        const SizedBox(width: AppSpacing.xs),
        AppChip(
          label: '7 ngày',
          selected: vm.period == DashboardPeriod.week,
          onSelected: (_) => vm.setPeriod(DashboardPeriod.week),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(tooltip: 'Tải lại', onPressed: vm.load, icon: const Icon(Icons.refresh)),
      ],
      child: ViewStateView<KioskStats>(
        state: vm.state,
        onRetry: vm.load,
        builder: (context, stats) => ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _Figure(label: 'Đơn đã giao', value: '${stats.deliveredCount}', icon: Icons.task_alt),
                _Figure(label: 'Doanh thu', value: formatVnd(stats.revenueVnd), icon: Icons.payments_outlined),
                _Figure(
                  label: 'Thời gian làm trung bình',
                  value: prepTimeLabel(stats.averagePrepSeconds),
                  icon: Icons.timer_outlined,
                ),
                _Figure(label: 'Đơn bị huỷ', value: '${stats.cancelledCount}', icon: Icons.cancel_outlined),
                _Figure(label: 'Đang xử lý', value: '${stats.activeCount}', icon: Icons.soup_kitchen_outlined),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AdminPanel(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _HourlyChart(stats: stats),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: SizedBox(
        width: 210,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(icon, color: colors.primaryText, size: 18),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(value, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xxs),
              Text(label, style: text.bodySmall?.copyWith(color: colors.muted, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Orders per hour of the day as bars; hours with no order still get a slot so the day reads left to right.
class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.stats});

  final KioskStats stats;

  static const _firstHour = 6, _lastHour = 20, _height = 180.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final byHour = stats.ordersByHour;
    final hours = [
      for (var h = _firstHour; h <= _lastHour; h++) h,
      ...byHour.keys.where((h) => h < _firstHour || h > _lastHour),
    ]..sort();
    final top = byHour.values.fold<int>(1, (a, b) => a > b ? a : b);
    final peak = stats.peakHour;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 20, color: colors.primaryText),
            const SizedBox(width: AppSpacing.xs),
            Text('Số đơn theo giờ', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          peak == null
              ? 'Chưa có đơn.'
              : 'Giờ đông nhất: ${peak}h (${byHour[peak]} đơn)'
                    '${stats.chartTruncated ? ' · biểu đồ tính từ các đơn gần nhất' : ''}',
          style: text.bodyMedium?.copyWith(color: colors.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          label:
              'Biểu đồ số đơn theo giờ: ${[for (final h in hours)
                if ((byHour[h] ?? 0) > 0) '${h}h ${byHour[h]} đơn'].join(', ')}',
          excludeSemantics: true,
          child: SizedBox(
            height: _height + 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final h in hours)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if ((byHour[h] ?? 0) > 0) Text('${byHour[h]}', style: text.labelLarge),
                          Container(
                            height: _height * (byHour[h] ?? 0) / top,
                            decoration: BoxDecoration(
                              color: h == peak ? scheme.primary : colors.selectedBorder,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.chip)),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text('${h}h', style: text.bodyMedium?.copyWith(color: colors.muted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
