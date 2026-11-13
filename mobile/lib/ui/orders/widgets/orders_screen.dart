import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/orders/view_models/orders_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrdersViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    // At about 1.5 times the text size the two labels no longer fit side by side ("Đang xử lý (2)" faded out).
    final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;

    Widget tabBody(Widget Function(List<Order> all) builder) => switch (vm.state) {
      ViewLoading<List<Order>>() => const LoadingView(),
      ViewEmpty<List<Order>>(:final message) => TestId(
        's08.empty',
        child: EmptyView(
          message: message ?? OrdersViewModel.emptyMessage,
          icon: Icons.receipt_long,
          actionLabel: 'Xem thực đơn',
          onAction: () => context.go(AppRoutes.menu),
        ),
      ),
      ViewError<List<Order>>(:final message) => TestId(
        's08.retry',
        child: ErrorView(message: message, onRetry: vm.load),
      ),
      ViewData<List<Order>>(:final data) => builder(data),
    };

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(header: true, child: const Text('Đơn hàng')),
          centerTitle: false,
          bottom: TabBar(
            isScrollable: largeText,
            tabAlignment: largeText ? TabAlignment.start : null,
            labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            unselectedLabelColor: colors.muted,
            tabs: [
              TestId('s08.tab.active', child: Tab(text: 'Đang xử lý (${vm.active.length})')),
              const TestId('s08.tab.history', child: Tab(text: 'Lịch sử')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            tabBody((_) => _ActiveTab(vm: vm)),
            tabBody((_) => _HistoryTab(vm: vm)),
          ],
        ),
      ),
    );
  }
}

const _listPadding = EdgeInsets.fromLTRB(
  AppSpacing.screenPadding,
  AppSpacing.md,
  AppSpacing.screenPadding,
  AppSpacing.lg,
);

class _ActiveTab extends StatelessWidget {
  const _ActiveTab({required this.vm});

  final OrdersViewModel vm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final active = vm.active;
    final recent = vm.recent;
    return ListView(
      padding: _listPadding,
      children: [
        if (active.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text('Không có đơn nào đang xử lý.', style: text.bodyMedium?.copyWith(color: colors.muted)),
          ),
        for (final order in active)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ActiveOrderCard(vm: vm, order: order),
          ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            header: true,
            child: Text('Đơn gần đây', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final order in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _FinishedOrderCard(vm: vm, order: order),
            ),
        ],
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.vm});

  final OrdersViewModel vm;

  @override
  Widget build(BuildContext context) {
    final finished = vm.finished;
    if (finished.isEmpty) {
      return const EmptyView(message: 'Chưa có đơn đã hoàn tất hoặc đã huỷ.', icon: Icons.history);
    }
    return ListView(
      padding: _listPadding,
      children: [
        for (final order in finished)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _FinishedOrderCard(vm: vm, order: order),
          ),
        TestId(
          's08.allHistory',
          child: AppButton(
            label: 'Xem toàn bộ lịch sử',
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.ordersHistory),
          ),
        ),
      ],
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.vm, required this.order});

  final OrdersViewModel vm;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final title = vm.title(order);
    final status = orderStatusLabel(order.status);
    void open() => context.push(AppRoutes.orderOf(order.id));
    // The whole card opens S07, as a finished order's card opens S12 (P-02: people tapped the card, not the button).
    return TestId(
      's08.order.${order.id}',
      child: Semantics(
        container: true,
        label: '$title. $status. ${vm.timing(order)}. Chạm để theo dõi đơn',
        child: Material(
          color: scheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: scheme.primary, width: 1.5),
          ),
          child: InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Side by side while they fit; at large text the badge moves under the title instead of overflowing.
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      StatusBadge(label: status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(orderItemsSummary(order), style: text.bodyMedium?.copyWith(color: colors.muted)),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 18, color: colors.muted),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Text(vm.timing(order), style: text.bodyMedium?.copyWith(color: colors.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: TestId(
                      's08.order.${order.id}.open',
                      child: AppButton(
                        label: 'Xem mã QR nhận món',
                        variant: AppButtonVariant.secondary,
                        onPressed: open,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinishedOrderCard extends StatelessWidget {
  const _FinishedOrderCard({required this.vm, required this.order});

  final OrdersViewModel vm;
  final Order order;

  Future<void> _reorder(BuildContext context) async {
    final router = GoRouter.of(context);
    final result = await vm.reorder.execute(order);
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok(:final value):
        showAddedSnackbar(
          context,
          message: 'Đã thêm $value món vào giỏ',
          onViewCart: () => router.push(AppRoutes.cart),
        );
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final delivered = order.status == OrderStatus.delivered;
    final title = vm.title(order);
    final statusColor = delivered ? colors.success : scheme.error;
    return TestId(
      's08.order.${order.id}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.orderDetailOf(order.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  label: '$title. ${vm.timing(order)}. ${orderItemsSummary(order)}. Chạm để xem chi tiết',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Icon(delivered ? Icons.check : Icons.close, size: 18, color: statusColor),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            vm.timing(order),
                            style: text.bodyMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(orderItemsSummary(order), style: text.bodyMedium?.copyWith(color: colors.muted)),
                    ],
                  ),
                ),
                ListenableBuilder(
                  listenable: vm.reorder,
                  builder: (context, _) => TestId(
                    's08.order.${order.id}.reorder',
                    child: TextButton.icon(
                      onPressed: vm.reorder.running ? null : () => _reorder(context),
                      icon: const Icon(Icons.replay),
                      label: const Text('Đặt lại món này'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primaryText,
                        minimumSize: const Size(AppA11y.minTouchTarget, AppA11y.minTouchTarget),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
