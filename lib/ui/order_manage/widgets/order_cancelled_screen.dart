import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/order_manage/view_models/order_cancelled_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S10: a cancelled order with who ended it, the refund and a one-tap reorder.
class OrderCancelledScreen extends StatelessWidget {
  const OrderCancelledScreen({super.key});

  Future<void> _reorder(BuildContext context, OrderCancelledViewModel vm) async {
    final router = GoRouter.of(context);
    final result = await vm.reorder.execute();
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
    final vm = context.watch<OrderCancelledViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Đơn đã huỷ', closes: true, onBack: () => context.go(AppRoutes.home)),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn hàng…'),
        ViewError(:final message) => TestId(
          's10.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          's10.empty',
          child: EmptyView(
            message: message ?? OrderCancelledViewModel.notFoundMessage,
            actionLabel: vm.notCancelled ? 'Xem đơn' : 'Về trang chủ',
            onAction: () => context.go(vm.notCancelled ? AppRoutes.orderOf(vm.orderId) : AppRoutes.home),
          ),
        ),
        ViewData(:final data) => _Body(vm: vm, order: data, onReorder: () => _reorder(context, vm)),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm, required this.order, required this.onReorder});

  final OrderCancelledViewModel vm;
  final Order order;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reason = vm.reasonLine;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      children: [
        TestId(
          's10.header',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đơn tại ${order.kioskName}', style: text.bodyMedium?.copyWith(color: colors.muted)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${order.orderCode}',
                          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const TestId('s10.status', child: StatusBadge(label: 'Đã huỷ', warning: true)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cancel_outlined, size: 20, color: scheme.error),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(vm.whoLine, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                  if (reason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: TestId('s10.reason', child: Text(reason, style: text.bodyMedium)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(vm.cancelledAtLine, style: text.bodyMedium?.copyWith(color: colors.muted)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TestId(
          's10.refund',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(vm.refunded ? Icons.currency_exchange : Icons.info_outline, color: colors.primaryText),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(vm.refundLine, style: text.bodyMedium)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TestId(
          's10.items',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vm.itemsLine, style: text.bodyMedium?.copyWith(color: colors.muted)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(vm.totalLine, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ListenableBuilder(
          listenable: vm.reorder,
          builder: (context, _) => TestId(
            's10.reorder',
            child: AppButton(
              label: 'Đặt lại món này',
              icon: Icons.replay,
              large: true,
              loading: vm.reorder.running,
              onPressed: vm.reorder.running ? null : onReorder,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TestId(
          's10.home',
          child: AppButton(
            label: 'Về trang chủ',
            icon: Icons.home_outlined,
            variant: AppButtonVariant.secondary,
            large: true,
            onPressed: () => context.go(AppRoutes.home),
          ),
        ),
      ],
    );
  }
}
