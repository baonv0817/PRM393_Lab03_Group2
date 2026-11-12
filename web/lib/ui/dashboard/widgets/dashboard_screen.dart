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
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        DashboardViewModel(orders: context.read<OrderRepository>(), kioskId: context.read<AdminSession>().kioskId!),
    child: const _DashboardView(),
  );
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    return AdminPage(
      title: 'Thống kê',
      subtitle: 'Tính trên máy chủ Firestore bằng truy vấn tổng hợp (count, sum, average), từ ${formatDate(vm.since)}.',
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
                _Figure(label: 'Đơn đã giao', value: '${stats.deliveredCount}', query: 'count()', icon: Icons.task_alt),
                _Figure(
                  label: 'Doanh thu',
                  value: formatVnd(stats.revenueVnd),
                  query: "sum('totalVnd')",
                  icon: Icons.payments_outlined,
                ),
                _Figure(
                  label: 'Thời gian làm trung bình',
                  value: prepTimeLabel(stats.averagePrepSeconds),
                  query: "average('prepSeconds')",
                  icon: Icons.timer_outlined,
                ),
                _Figure(
                  label: 'Đơn bị huỷ',
                  value: '${stats.cancelledCount}',
                  query: 'count()',
                  icon: Icons.cancel_outlined,
                ),
                _Figure(
                  label: 'Đang xử lý',
                  value: '${stats.activeCount}',
                  query: 'count()',
                  icon: Icons.soup_kitchen_outlined,
                ),
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
  const _Figure({required this.label, required this.value, required this.query, required this.icon});

  final String label;
  final String value;
  final String query;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: SizedBox(
        width: 200,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colors.primaryText),
                const SizedBox(height: AppSpacing.xs),
                Text(value, style: text.headlineMedium),
                Text(label, style: text.bodyMedium),
                Text(query, style: text.bodyMedium?.copyWith(color: colors.muted)),
              ],
            ),
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
        Text('Số đơn theo giờ', style: text.titleMedium),
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
