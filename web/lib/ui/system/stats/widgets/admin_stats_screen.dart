import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_admin/ui/system/stats/view_models/admin_stats_view_model.dart';
import 'package:breakbite_admin/ui/system/stats/widgets/insight_card.dart';
import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/theme/chart_palette.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// 1.250.000 as "1,25 tr", 48.000 as "48k": a short form for the axes of a chart.
String _short(num vnd) {
  if (vnd >= 1000000) return '${(vnd / 1000000).toStringAsFixed(vnd % 1000000 == 0 ? 0 : 1).replaceAll('.', ',')} tr';
  if (vnd >= 1000) return '${(vnd / 1000).round()}k';
  return '${vnd.round()}';
}

/// A08: how the kiosks are doing over a period, the way a shop owner reads it: the takings and what changed since
/// the period before, the takings day by day and kiosk by kiosk, how the orders ended, when the rush is, and what
/// sells.
class AdminStatsScreen extends StatelessWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminStatsViewModel>();
    return AdminPage(
      title: 'Thống kê',
      subtitle: vm.kioskId == null
          ? 'Mọi kiosk, ${vm.days} ngày gần nhất'
          : '${vm.kioskName(vm.kioskId!)}, ${vm.days} ngày gần nhất',
      actions: [
        SizedBox(
          width: 240,
          child: TestId(
            'a08.kiosk',
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: vm.kioskId,
              decoration: const InputDecoration(labelText: 'Kiosk'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Mọi kiosk')),
                for (final k in vm.kiosks) DropdownMenuItem<String?>(value: k.id, child: Text(k.name)),
              ],
              onChanged: vm.setKiosk,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final days in AdminStatsViewModel.periods)
              TestId(
                'a08.days.$days',
                child: AppChip(label: '$days ngày', selected: vm.days == days, onSelected: (_) => vm.setDays(days)),
              ),
          ],
        ),
      ],
      child: switch (vm.state) {
        ViewLoading() => const _StatsSkeleton(),
        ViewError(:final message) => TestId(
          'a08.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'a08.empty',
          child: EmptyView(message: message ?? AdminStatsViewModel.emptyMessage, icon: Icons.bar_chart),
        ),
        ViewData(:final data) => _Dashboard(report: data, previous: vm.previous, kioskName: vm.kioskName),
      },
    );
  }
}

/// A frame of grey blocks where the figures will be, so the page does not jump when they arrive.
class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Expanded(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.appColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[block(96), if (i < 3) const SizedBox(width: AppSpacing.sm)],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            block(280),
            const SizedBox(width: AppSpacing.sm),
            block(280),
          ],
        ),
      ],
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.report, required this.previous, required this.kioskName});

  final SalesReport report;
  final SalesReport? previous;
  final String Function(String id) kioskName;

  @override
  Widget build(BuildContext context) {
    final before = previous;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 980;
        Widget pair(Widget left, Widget right, {int leftFlex = 2}) => wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: leftFlex, child: left),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: right),
                ],
              )
            : Column(
                children: [
                  left,
                  const SizedBox(height: AppSpacing.md),
                  right,
                ],
              );
        final kpis = [
          _Kpi(
            id: 'a08.revenue',
            label: 'Doanh thu',
            value: report.revenueVnd,
            format: formatVnd,
            change: before == null ? null : AdminStatsViewModel.change(report.revenueVnd, before.revenueVnd),
          ),
          _Kpi(
            id: 'a08.orders',
            label: 'Số đơn',
            value: report.orders,
            format: (v) => '$v',
            change: before == null ? null : AdminStatsViewModel.change(report.orders, before.orders),
          ),
          _Kpi(
            id: 'a08.average',
            label: 'Giá trị mỗi đơn',
            value: report.averageOrderVnd,
            format: formatVnd,
            change: before == null ? null : AdminStatsViewModel.change(report.averageOrderVnd, before.averageOrderVnd),
          ),
          _Kpi(
            id: 'a08.cancelled',
            label: 'Tỉ lệ huỷ',
            value: (report.cancelRate * 100).round(),
            format: (v) => '$v%',
            note: '${report.cancelled} trên ${report.orders} đơn',
            lowerIsBetter: true,
            change: before == null || before.cancelRate == 0
                ? null
                : (report.cancelRate - before.cancelRate) / before.cancelRate,
          ),
          _Kpi(
            id: 'a08.prep',
            label: 'Làm trung bình',
            value: report.averagePrepSeconds?.round() ?? 0,
            format: (seconds) => report.averagePrepSeconds == null
                ? '-'
                : '${(seconds / 60).toStringAsFixed(1).replaceAll('.', ',')} phút',
            note: 'từ lúc nhận đến lúc xong',
            lowerIsBetter: true,
            change: before?.averagePrepSeconds == null || report.averagePrepSeconds == null
                ? null
                : AdminStatsViewModel.change(report.averagePrepSeconds!, before!.averagePrepSeconds!),
          ),
        ];
        return ListView(
          children: [
            if (report.truncated)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TestId(
                  'a08.truncated',
                  child: Text(
                    'Khoảng thời gian này có nhiều hơn ${AdminOrderRepository.maxRange} đơn: số liệu tính trên các đơn mới nhất. Chọn khoảng ngắn hơn để đủ.',
                    style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            const InsightCard(),
            if (context.read<AdminStatsViewModel>().insightAvailable) const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (i, kpi) in kpis.indexed)
                  SizedBox(
                    width: wide ? (box.maxWidth - AppSpacing.sm * 4) / 5 : (box.maxWidth - AppSpacing.sm) / 2,
                    child: Reveal(
                      delay: Duration(milliseconds: 60 * i),
                      child: kpi,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            pair(
              Reveal(
                delay: const Duration(milliseconds: 240),
                child: _DailyChart(report: report, kioskName: kioskName),
              ),
              Reveal(
                delay: const Duration(milliseconds: 300),
                child: _StatusDonut(report: report),
              ),
              leftFlex: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            pair(
              Reveal(
                delay: const Duration(milliseconds: 360),
                child: _KioskRanking(report: report),
              ),
              Reveal(
                delay: const Duration(milliseconds: 420),
                child: _RushHours(report: report),
              ),
              leftFlex: 1,
            ),
            const SizedBox(height: AppSpacing.md),
            Reveal(
              delay: const Duration(milliseconds: 480),
              child: _TopDishes(report: report),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

/// A white panel with a title: every block of the dashboard sits in one, so the page reads as a set of figures.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, this.hint, this.trailing, required this.child});

  final String title;
  final String? hint;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return Container(
      width: double.infinity,
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
              Expanded(
                child: Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              ?trailing,
            ],
          ),
          if (hint != null) Text(hint!, style: text.bodySmall?.copyWith(color: colors.muted)),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.id,
    required this.label,
    required this.value,
    required this.format,
    this.change,
    this.note,
    this.lowerIsBetter = false,
  });

  final String id;
  final String label;
  final int value;
  final String Function(int value) format;

  /// The change against the period before, as a fraction, or `null` when there is nothing to compare with.
  final double? change;
  final String? note;

  /// For a figure where less is better (cancellations, time to make): a fall is shown as good news.
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final c = change;
    final good = c == null ? null : (lowerIsBetter ? c <= 0 : c >= 0);
    final tone = good == null ? colors.muted : (good ? colors.success : scheme.error);
    return TestId(
      id,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.bodySmall?.copyWith(color: colors.muted)),
            const SizedBox(height: AppSpacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUp(
                value: value,
                format: format,
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            if (c != null)
              Row(
                children: [
                  Icon(
                    c == 0 ? Icons.remove : (c > 0 ? Icons.arrow_upward : Icons.arrow_downward),
                    size: 14,
                    color: tone,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${(c.abs() * 100).round()}%',
                    style: text.bodySmall?.copyWith(color: tone, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: Text(
                      'so với kỳ trước',
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: colors.muted),
                    ),
                  ),
                ],
              )
            else
              Text(note ?? 'chưa có kỳ trước để so', style: text.bodySmall?.copyWith(color: colors.muted)),
          ],
        ),
      ),
    );
  }
}

/// The takings of each day as a column, split by kiosk, so it is clear both which days were busy and which kiosk
/// carried them. Touch a column for the figures of that day.
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.report, required this.kioskName});

  final SalesReport report;
  final String Function(String id) kioskName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final kiosks = [for (final k in report.byKiosk) k.kioskId];
    final days = report.byDay;
    final best = report.bestDayRevenueVnd;
    final top = best == 0 ? 1.0 : best * 1.15;
    final labelEvery = days.length > 14 ? 3 : (days.length > 7 ? 2 : 1);
    return _Panel(
      title: 'Doanh thu theo ngày',
      hint: 'Chỉ tính đơn đã giao, chia theo kiosk',
      trailing: Wrap(
        spacing: AppSpacing.sm,
        children: [
          for (final (i, id) in kiosks.indexed)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: ChartPalette.seriesAt(i), borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 6),
                Text(kioskName(id), style: text.bodySmall),
              ],
            ),
        ],
      ),
      child: TestId(
        'a08.days',
        child: SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              maxY: top,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: top / 4,
                getDrawingHorizontalLine: (_) => FlLine(color: colors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: top / 4,
                    getTitlesWidget: (v, meta) => v == meta.max
                        ? const SizedBox.shrink()
                        : SideTitleWidget(
                            meta: meta,
                            child: Text(_short(v), style: text.bodySmall?.copyWith(color: colors.muted)),
                          ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length || i % labelEvery != 0) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(_day(days[i].day), style: text.bodySmall?.copyWith(color: colors.muted)),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Theme.of(context).colorScheme.onSurface,
                  getTooltipItem: (group, _, rod, _) {
                    final d = days[group.x];
                    final lines = [
                      '${_day(d.day)}: ${formatVnd(d.revenueVnd)}',
                      for (final id in kiosks)
                        if ((d.revenueByKiosk[id] ?? 0) > 0) '${kioskName(id)}: ${formatVnd(d.revenueByKiosk[id]!)}',
                      '${d.orders} đơn',
                    ];
                    return BarTooltipItem(
                      lines.join('\n'),
                      text.bodySmall!.copyWith(color: Theme.of(context).colorScheme.surface),
                    );
                  },
                ),
              ),
              barGroups: [
                for (final (i, d) in days.indexed)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: d.revenueVnd.toDouble(),
                        width: days.length > 14 ? 10 : 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        color: ChartPalette.quiet,
                        rodStackItems: _stack(d, kiosks),
                      ),
                    ],
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
  }

  List<BarChartRodStackItem> _stack(DaySales d, List<String> kiosks) {
    var from = 0.0;
    final items = <BarChartRodStackItem>[];
    for (final (i, id) in kiosks.indexed) {
      final v = (d.revenueByKiosk[id] ?? 0).toDouble();
      if (v <= 0) continue;
      items.add(BarChartRodStackItem(from, from + v, ChartPalette.seriesAt(i)));
      from += v;
    }
    return items;
  }
}

/// How the orders of the period ended: handed over, still being made, or cancelled.
class _StatusDonut extends StatelessWidget {
  const _StatusDonut({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final parts = [
      ('Đã giao', report.delivered, colors.success),
      ('Đang xử lý', report.active, scheme.primary),
      ('Đã huỷ', report.cancelled, scheme.error),
    ];
    return _Panel(
      title: 'Đơn hàng theo trạng thái',
      hint: '${report.orders} đơn đã đặt',
      child: TestId(
        'a08.status',
        child: Column(
          children: [
            SizedBox(
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 56,
                      sectionsSpace: 3,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(enabled: false),
                      sections: [
                        for (final (_, n, color) in parts)
                          if (n > 0)
                            PieChartSectionData(value: n.toDouble(), color: color, radius: 22, showTitle: false),
                      ],
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${report.orders}', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text('đơn', style: text.bodySmall?.copyWith(color: colors.muted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (label, n, color) in parts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(label, style: text.bodyMedium)),
                    Text(
                      '$n  ·  ${report.orders == 0 ? 0 : (n * 100 / report.orders).round()}%',
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The kiosks side by side by takings, each with its share of the whole, how many orders it took and how many of
/// them it lost to cancellations.
class _KioskRanking extends StatelessWidget {
  const _KioskRanking({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final best = report.byKiosk.fold(0, (m, k) => k.revenueVnd > m ? k.revenueVnd : m);
    return _Panel(
      title: 'Doanh thu theo kiosk',
      hint: report.revenueVnd == 0 ? 'Chưa có đơn nào được giao' : 'Phần trăm là tỉ trọng trong tổng doanh thu',
      child: TestId(
        'a08.kiosks',
        child: Column(
          children: [
            for (final (i, k) in report.byKiosk.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(k.kioskName, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        Text(formatVnd(k.revenueVnd), style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                        SizedBox(
                          width: 52,
                          child: Text(
                            report.revenueVnd == 0 ? '0%' : '${(k.revenueVnd * 100 / report.revenueVnd).round()}%',
                            textAlign: TextAlign.end,
                            style: text.bodySmall?.copyWith(color: colors.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _Bar(fraction: best == 0 ? 0 : k.revenueVnd / best, color: ChartPalette.seriesAt(i), height: 10),
                    const SizedBox(height: 4),
                    Text(
                      '${k.delivered} đã giao trên ${k.orders} đơn, ${k.cancelled} huỷ',
                      style: text.bodySmall?.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal bar that grows to [fraction] of its width when it appears.
class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color, required this.height});

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        width: double.infinity,
        color: context.appColors.surfaceVariant,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction.clamp(0, 1).toDouble()),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, f, _) => FractionallySizedBox(
            widthFactor: f,
            child: Container(color: color),
          ),
        ),
      ),
    );
  }
}

/// Orders by hour of the day, with the busiest hour in the accent colour: when to have more hands at the counter.
class _RushHours extends StatelessWidget {
  const _RushHours({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final hours = report.byHour;
    final used = [
      for (var h = 0; h < 24; h++)
        if (hours[h] > 0) h,
    ];
    final lo = used.isEmpty ? 7 : (used.first < 7 ? used.first : 7);
    final hi = used.isEmpty ? 18 : (used.last > 18 ? used.last : 18);
    final peak = hours.fold(0, (m, v) => v > m ? v : m);
    final peakHour = peak == 0 ? null : hours.indexOf(peak);
    return _Panel(
      title: 'Giờ cao điểm',
      hint: peakHour == null ? 'Chưa có đơn' : 'Đông nhất lúc $peakHour:00, $peak đơn trong kỳ',
      child: TestId(
        'a08.hours',
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: peak == 0 ? 1 : peak * 1.2,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: peak <= 4 ? 1 : null,
                getDrawingHorizontalLine: (_) => FlLine(color: colors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) => v == meta.max || v % 1 != 0
                        ? const SizedBox.shrink()
                        : SideTitleWidget(
                            meta: meta,
                            child: Text('${v.toInt()}', style: text.bodySmall?.copyWith(color: colors.muted)),
                          ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, meta) {
                      final h = v.toInt() + lo;
                      return h % 2 == 1 && h != hi
                          ? const SizedBox.shrink()
                          : SideTitleWidget(
                              meta: meta,
                              child: Text('${h}h', style: text.bodySmall?.copyWith(color: colors.muted)),
                            );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.onSurface,
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${group.x + lo}:00  ·  ${rod.toY.toInt()} đơn',
                    text.bodySmall!.copyWith(color: scheme.surface),
                  ),
                ),
              ),
              barGroups: [
                for (var h = lo; h <= hi; h++)
                  BarChartGroupData(
                    x: h - lo,
                    barRods: [
                      BarChartRodData(
                        toY: hours[h].toDouble(),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        color: h == peakHour ? scheme.primary : ChartPalette.quiet,
                      ),
                    ],
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
  }
}

/// The dishes that sold most, with a bar to compare them at a glance.
class _TopDishes extends StatelessWidget {
  const _TopDishes({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final most = report.topDishes.isEmpty ? 0 : report.topDishes.first.quantity;
    return _Panel(
      title: 'Món bán chạy',
      hint: report.topDishes.isEmpty ? 'Chưa có món nào được giao' : 'Theo số phần đã giao',
      child: TestId(
        'a08.dishes',
        child: Column(
          children: [
            for (final (i, d) in report.topDishes.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('${i + 1}', style: text.bodyMedium?.copyWith(color: colors.muted)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(d.name, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: _Bar(
                          fraction: most == 0 ? 0 : d.quantity / most,
                          color: i == 0 ? Theme.of(context).colorScheme.primary : ChartPalette.seriesAt(2),
                          height: 8,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: Text(
                        '${d.quantity} phần  ·  ${formatVnd(d.revenueVnd)}',
                        textAlign: TextAlign.end,
                        style: text.bodySmall?.copyWith(color: colors.muted),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
