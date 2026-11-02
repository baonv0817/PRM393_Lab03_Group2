import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/order_manage/view_models/order_history_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S11: finished and cancelled orders grouped by week or month; each opens its detail (S12).
class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  Future<void> _loadMore(BuildContext context, OrderHistoryViewModel vm) async {
    final result = await vm.loadMore.execute();
    if (!context.mounted || result == null) return;
    if (result case Err(:final error)) showAppMessage(context, error.message);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderHistoryViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: 'Lịch sử đơn',
        onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.orders),
      ),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải lịch sử đơn…'),
        ViewError(:final message) => TestId(
          's11.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          's11.empty',
          child: EmptyView(
            message: message ?? OrderHistoryViewModel.emptyMessage,
            icon: Icons.history,
            actionLabel: 'Xem thực đơn',
            onAction: () => context.go(AppRoutes.menu),
          ),
        ),
        ViewData() => _Body(vm: vm, onLoadMore: () => _loadMore(context, vm)),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm, required this.onLoadMore});

  final OrderHistoryViewModel vm;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            TestId(
              's11.grouping.week',
              child: AppChip(
                label: 'Theo tuần',
                selected: vm.grouping == HistoryGrouping.week,
                onSelected: (_) => vm.setGrouping(HistoryGrouping.week),
              ),
            ),
            TestId(
              's11.grouping.month',
              child: AppChip(
                label: 'Theo tháng',
                selected: vm.grouping == HistoryGrouping.month,
                onSelected: (_) => vm.setGrouping(HistoryGrouping.month),
              ),
            ),
          ],
        ),
        for (final group in vm.groups) ...[
          TestId(
            's11.group.${group.id}',
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
              child: Semantics(
                header: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(group.summary, style: text.bodyMedium?.copyWith(color: colors.muted)),
                  ],
                ),
              ),
            ),
          ),
          for (final order in group.orders)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _OrderRow(vm: vm, order: order),
            ),
        ],
        if (vm.hasMore)
          ListenableBuilder(
            listenable: vm.loadMore,
            builder: (context, _) => TestId(
              's11.more',
              child: AppButton(
                label: 'Xem đơn cũ hơn',
                icon: Icons.expand_more,
                variant: AppButtonVariant.secondary,
                loading: vm.loadMore.running,
                onPressed: vm.loadMore.running ? null : onLoadMore,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Đã hiển thị tất cả đơn của bạn.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.muted),
            ),
          ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.vm, required this.order});

  final OrderHistoryViewModel vm;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final delivered = order.status == OrderStatus.delivered;
    final statusColor = delivered ? colors.success : scheme.error;
    final title = vm.title(order);
    final ending = vm.ending(order);
    return TestId(
      's11.order.${order.id}',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label: '$title. $ending. ${orderItemsSummary(order)}. Chạm để xem chi tiết',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => context.push(AppRoutes.orderDetailOf(order.id)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Icon(delivered ? Icons.check : Icons.close, size: 18, color: statusColor),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          ending,
                          style: text.bodyMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(orderItemsSummary(order), style: text.bodyMedium?.copyWith(color: colors.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
