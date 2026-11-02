import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/ui/seller_shop/view_models/shift_stats_view_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// K11: the figures of today's shift for the staff member's kiosk.
class ShiftStatsScreen extends StatelessWidget {
  const ShiftStatsScreen({super.key});

  void _back(BuildContext context) => context.canPop() ? context.pop() : context.go(AppRoutes.sellerShop);

  Future<void> _refresh(BuildContext context, ShiftStatsViewModel vm) async {
    await vm.load();
    if (!context.mounted) return;
    final error = vm.takeRefreshError();
    if (error != null) showAppMessage(context, 'Chưa cập nhật được: $error');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShiftStatsViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: 'Ca hôm nay',
        onBack: () => _back(context),
        actions: [
          if (vm.hasKiosk)
            TestId(
              'k11.refresh',
              child: AppIconButton(
                icon: Icons.refresh,
                semanticLabel: 'Làm mới thống kê',
                onPressed: vm.refreshing ? null : () => _refresh(context, vm),
              ),
            ),
        ],
      ),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tính thống kê…'),
        ViewError(:final message) => TestId(
          'k11.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'k11.empty',
          child: EmptyView(
            message: message ?? ShiftStatsViewModel.emptyMessage,
            icon: Icons.bar_chart,
            actionLabel: vm.hasKiosk ? 'Làm mới' : null,
            onAction: vm.hasKiosk ? () => _refresh(context, vm) : null,
          ),
        ),
        ViewData() => RefreshIndicator(
          onRefresh: () => _refresh(context, vm),
          child: _Body(vm: vm),
        ),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm});

  final ShiftStatsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final stats = vm.stats;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.xl,
          ),
          children: [
            _FigureRow(
              left: _Figure(id: 'k11.delivered', label: 'Đơn đã làm', value: '${stats.deliveredCount}'),
              right: _Figure(id: 'k11.revenue', label: 'Doanh thu', value: vm.revenueLabel),
            ),
            const SizedBox(height: AppSpacing.sm),
            _FigureRow(
              left: _Figure(id: 'k11.prep', label: 'Làm trung bình', value: vm.averagePrepLabel),
              right: _Figure(id: 'k11.cancelled', label: 'Đơn huỷ', value: '${stats.cancelledCount}'),
            ),
            const SizedBox(height: AppSpacing.md),
            _Chart(vm: vm),
            const SizedBox(height: AppSpacing.sm),
            TestId(
              'k11.active',
              child: Text(
                'Đang xử lý: ${stats.activeCount} đơn',
                style: text.bodyMedium?.copyWith(color: colors.muted),
              ),
            ),
            TestId(
              'k11.shift',
              child: Text(
                [
                  if (vm.kioskName.isNotEmpty) vm.kioskName,
                  vm.shiftLabel,
                  vm.updatedLabel,
                ].where((e) => e.isNotEmpty).join(' · '),
                style: text.bodyMedium?.copyWith(color: colors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two figures side by side with the same height; a ListView gives its children unbounded height, so the
/// row needs [IntrinsicHeight] to stretch them.
class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: right),
      ],
    ),
  );
}

class _Figure extends StatelessWidget {
  const _Figure({required this.id, required this.label, required this.value});

  final String id;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return TestId(
      id,
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: ProfileSection(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodyMedium?.copyWith(color: colors.muted)),
                const SizedBox(height: AppSpacing.xxs),
                Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Orders per hour as plain bars; the chart is short enough to need no package.
class _Chart extends StatelessWidget {
  const _Chart({required this.vm});

  final ShiftStatsViewModel vm;

  static const _barWidth = 36.0;
  static const _plotHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bars = vm.bars;
    final peak = vm.maxBarCount;
    final peakLabel = vm.peakLabel;
    return TestId(
      'k11.chart',
      child: ProfileSection(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Số đơn theo giờ', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (peakLabel != null) Text(peakLabel, style: text.bodyMedium?.copyWith(color: colors.muted)),
              const SizedBox(height: AppSpacing.sm),
              if (bars.isEmpty)
                Text('Chưa có đơn nào để vẽ biểu đồ.', style: text.bodyMedium?.copyWith(color: colors.muted))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final bar in bars)
                        TestId(
                          'k11.bar.${bar.hour}',
                          child: Semantics(
                            label: '${bar.hour} giờ: ${bar.count} đơn',
                            excludeSemantics: true,
                            child: SizedBox(
                              width: _barWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${bar.count}', style: text.labelMedium),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Container(
                                    width: _barWidth - AppSpacing.md,
                                    height: peak == 0 ? 2 : (_plotHeight * bar.count / peak).clamp(2, _plotHeight),
                                    decoration: BoxDecoration(
                                      color: bar.hour == vm.stats.peakHour && bar.count > 0
                                          ? scheme.primary
                                          : colors.border,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(AppRadius.chip / 2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(bar.label, style: text.labelMedium?.copyWith(color: colors.muted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (vm.stats.chartTruncated) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(ShiftStatsViewModel.truncatedNote, style: text.bodyMedium?.copyWith(color: colors.muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
