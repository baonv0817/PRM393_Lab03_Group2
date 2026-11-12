import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_order_view_model.dart';
import 'package:breakbite/ui/seller_orders/widgets/reject_order_dialog.dart';
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

/// Asks why, turns the order down (K12) and goes back to the list. Shared by K03 and K04.
Future<void> rejectFlow(BuildContext context, SellerOrderViewModel vm) async {
  final order = vm.order;
  if (order == null) return;
  final paid = order.paymentStatus == PaymentStatus.paid;
  final reason = await showRejectOrderDialog(
    context,
    orderCode: order.orderCode.isEmpty ? order.id : order.orderCode,
    paid: paid,
  );
  if (reason == null || !context.mounted) return;
  final result = await vm.reject(reason);
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      showAppMessage(context, paid ? 'Đã từ chối đơn. Khách được hoàn tiền tự động.' : 'Đã từ chối đơn.');
      context.go(AppRoutes.sellerOrders);
    case Err(:final error):
      showAppMessage(context, error.message);
  }
}

/// K03: a new order, read in full before it is accepted or turned down.
class SellerOrderScreen extends StatelessWidget {
  const SellerOrderScreen({super.key});

  Future<void> _accept(BuildContext context, SellerOrderViewModel vm) async {
    final id = vm.order?.id;
    final result = await vm.accept();
    if (!context.mounted) return;
    switch (result) {
      case Ok() when id != null:
        context.pushReplacement(AppRoutes.sellerOrderPreparingOf(id));
      case Ok():
        break;
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellerOrderViewModel>();
    final order = vm.order;
    return Scaffold(
      appBar: AppTopBar(
        title: order == null ? 'Chi tiết đơn' : 'Đơn #${order.orderCode.isEmpty ? order.id : order.orderCode}',
        onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.sellerOrders),
        actions: [
          if (order != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: StatusBadge(
                  label: sellerOrderStatusLabel(order),
                  warning: order.status == OrderStatus.cancelled,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: order == null ? null : _Actions(order: order, vm: vm, onAccept: () => _accept(context, vm)),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn…'),
        ViewError(:final message) => TestId(
          'k03.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'k03.empty',
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
    final text = Theme.of(context).textTheme;
    final pickup = vm.pickupTime;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            TestId(
              'k03.when',
              child: SellerCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.schedule, color: colors.primaryText),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickup == null
                                ? 'Chưa hẹn giờ nhận'
                                : 'Nhận lúc ${formatTime(pickup)} (${formatTimeLeft(pickup, now: vm.now)})',
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Đặt lúc ${formatTime(order.createdAt)}${order.kioskName.isEmpty ? '' : ' · ${order.kioskName}'}',
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
            OrderLinesCard(order: order),
            OrderNoteCard(order: order),
            const SizedBox(height: AppSpacing.sm),
            OrderPaymentCard(order: order),
            if (order.status == OrderStatus.cancelled && (order.cancelReason ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              TestId(
                'k03.cancelReason',
                child: SellerCard(
                  child: Text(
                    'Đã huỷ${order.cancelledBy == CancelledBy.staff ? ' bởi quầy' : ' bởi khách'}: ${order.cancelReason}',
                    style: text.bodyLarge,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.order, required this.vm, required this.onAccept});

  final Order order;
  final SellerOrderViewModel vm;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final id = order.id;
    switch (order.status) {
      case OrderStatus.pending:
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.xs,
              AppSpacing.screenPadding,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TestId(
                  'k03.accept',
                  child: AppButton(label: 'Nhận đơn và bắt đầu làm', loading: vm.busy, onPressed: onAccept),
                ),
                const SizedBox(height: AppSpacing.xs),
                TestId(
                  'k03.reject',
                  child: AppButton(
                    label: 'Từ chối đơn',
                    variant: AppButtonVariant.text,
                    onPressed: vm.busy ? null : () => rejectFlow(context, vm),
                  ),
                ),
              ],
            ),
          ),
        );
      case OrderStatus.preparing:
        return BottomActionButton(
          label: 'Xem đơn đang làm',
          testId: 'k03.toPreparing',
          onPressed: () => context.pushReplacement(AppRoutes.sellerOrderPreparingOf(id)),
        );
      case OrderStatus.ready:
        return BottomActionButton(
          label: 'Giao món',
          testId: 'k03.toDeliver',
          onPressed: () => context.pushReplacement(AppRoutes.sellerOrderDeliverOf(id)),
        );
      case OrderStatus.delivered || OrderStatus.cancelled:
        return const SizedBox.shrink();
    }
  }
}
