import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_order_view_model.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_order_parts.dart';
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

/// K06 and K06-CASH: the code is right, the order is in front of staff. A paid order is confirmed with one
/// tap; a cash order first reminds staff of the amount to collect.
class SellerDeliverScreen extends StatelessWidget {
  const SellerDeliverScreen({super.key});

  Future<void> _deliver(BuildContext context, SellerOrderViewModel vm) async {
    final cash = vm.isCashToCollect;
    final result = await vm.deliver();
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        showAppMessage(context, cash ? 'Đã thu tiền và giao món.' : 'Đã giao món.');
        context.go(AppRoutes.sellerOrders);
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellerOrderViewModel>();
    final order = vm.order;
    final canDeliver = order != null && order.status == OrderStatus.ready;
    return Scaffold(
      appBar: AppTopBar(
        title: 'Xác nhận giao món',
        onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.sellerScan),
      ),
      bottomNavigationBar: canDeliver
          ? BottomActionButton(
              label: vm.isCashToCollect ? 'Đã thu tiền và giao món' : 'Xác nhận đã giao món',
              testId: vm.isCashToCollect ? 'k06.cash.confirm' : 'k06.confirm',
              loading: vm.busy,
              onPressed: () => _deliver(context, vm),
            )
          : null,
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn…'),
        ViewError(:final message) => TestId(
          'k06.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'k06.empty',
          child: EmptyView(message: message ?? SellerOrderViewModel.notFoundMessage, icon: Icons.receipt_long_outlined),
        ),
        ViewData(:final data) => _Body(order: data, vm: vm),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order, required this.vm});

  final Order order;
  final SellerOrderViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ready = order.status == OrderStatus.ready;
    final code = order.orderCode.isEmpty ? order.id : order.orderCode;
    final readyAt = order.readyAt;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            TestId(
              ready ? 'k06.valid' : 'k06.notReady',
              child: SellerCard(
                borderColor: ready ? colors.success : scheme.error,
                borderWidth: 2,
                child: Row(
                  children: [
                    Icon(ready ? Icons.check_circle : Icons.error, color: ready ? colors.success : scheme.error),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ready ? 'Mã hợp lệ · #$code' : 'Đơn #$code ${orderStatusLabel(order.status).toLowerCase()}',
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            ready
                                ? (readyAt == null ? 'Sẵn sàng giao' : 'Sẵn sàng từ ${formatTime(readyAt)}')
                                : 'Chỉ giao được đơn ở trạng thái "Sẵn sàng".',
                            style: text.bodyMedium?.copyWith(color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OrderLinesCard(order: order, idPrefix: 'k06'),
            const SizedBox(height: AppSpacing.sm),
            if (vm.isCashToCollect && ready)
              TestId(
                'k06.cash',
                child: SellerCard(
                  color: colors.selected,
                  borderColor: colors.selectedBorder,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.payments_outlined, color: colors.primaryText),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thu tiền mặt ${formatVnd(order.totalVnd)}',
                              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Thu tiền trước khi giao món. Khách chọn trả tại quầy.',
                              style: text.bodyMedium?.copyWith(color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              OrderPaymentCard(order: order, idPrefix: 'k06'),
          ],
        ),
      ),
    );
  }
}
