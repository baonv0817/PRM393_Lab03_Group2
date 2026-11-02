import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/order_manage/view_models/pickup_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S20: the pickup QR code at full size, to scan at the kiosk.
class PickupScreen extends StatelessWidget {
  const PickupScreen({super.key});

  void _back(BuildContext context, PickupViewModel vm) =>
      context.canPop() ? context.pop() : context.go(AppRoutes.orderOf(vm.orderId));

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PickupViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Mã nhận món', closes: true, onBack: () => _back(context, vm)),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn hàng…'),
        ViewError(:final message) => TestId(
          's20.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          's20.empty',
          child: EmptyView(
            message: message ?? PickupViewModel.notFoundMessage,
            actionLabel: 'Xem đơn hàng',
            onAction: () => context.go(AppRoutes.orders),
          ),
        ),
        ViewData(:final data) => _Body(vm: vm, order: data, onClose: () => _back(context, vm)),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm, required this.order, required this.onClose});

  final PickupViewModel vm;
  final Order order;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final qrSize = (width - 2 * (AppSpacing.screenPadding + AppSpacing.md + AppSpacing.xs)).clamp(160, 320).toDouble();
    final payment = vm.paymentLine;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      children: [
        TestId(
          's20.card',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Text(
                    'Đơn #${order.orderCode} · ${order.kioskName}',
                    style: text.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (vm.usable) ...[
                    TestId(
                      's20.qr',
                      child: PickupQrCode(
                        data: vm.qrPayload,
                        size: qrSize,
                        semanticLabel: 'Mã QR nhận món, mã số ${order.pickupCode.split('').join(' ')}',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Mã số', style: text.bodyMedium?.copyWith(color: colors.muted)),
                    TestId(
                      's20.code',
                      child: Semantics(
                        label: 'Mã số ${order.pickupCode.split('').join(' ')}',
                        excludeSemantics: true,
                        child: Text(
                          vm.codeText,
                          style: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 4),
                        ),
                      ),
                    ),
                  ] else
                    TestId(
                      's20.unavailable',
                      child: Column(
                        children: [
                          Icon(
                            order.status == OrderStatus.delivered ? Icons.check_circle_outline : Icons.cancel_outlined,
                            size: 64,
                            color: order.status == OrderStatus.delivered ? colors.success : scheme.error,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Mã này đã hết hiệu lực',
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  TestId(
                    's20.status',
                    child: Semantics(
                      liveRegion: true,
                      child: Text(vm.statusLine, textAlign: TextAlign.center, style: text.bodyLarge),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TestId(
          's20.summary',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vm.summaryLine, style: text.bodyMedium?.copyWith(color: colors.muted)),
                  if (payment != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TestId(
                      's20.payment',
                      child: Row(
                        children: [
                          Icon(Icons.payments_outlined, color: colors.primaryText),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(payment, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!vm.usable)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TestId(
              's20.detail',
              child: AppButton(
                label: 'Xem chi tiết đơn',
                icon: Icons.receipt_long,
                large: true,
                onPressed: () => context.push(AppRoutes.orderDetailOf(order.id)),
              ),
            ),
          ),
        TestId(
          's20.close',
          child: AppButton(label: 'Quay lại đơn', variant: AppButtonVariant.secondary, large: true, onPressed: onClose),
        ),
      ],
    );
  }
}
