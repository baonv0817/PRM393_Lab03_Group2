import 'dart:async';

import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/orders/view_models/order_tracking_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _cancel(OrderTrackingViewModel vm, Order order) async {
    final confirmed = await showAppDialog(
      context,
      title: 'Huỷ đơn #${order.orderCode}?',
      message: vm.cancelMessage,
      confirmLabel: 'Huỷ đơn',
      cancelLabel: 'Giữ đơn',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final result = await vm.cancel.execute();
    if (!mounted || result == null) return;
    switch (result) {
      case Ok():
        context.go(AppRoutes.orderCancelledOf(order.id));
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  void _directions(OrderTrackingViewModel vm, Order order) {
    final kiosk = vm.kiosk;
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.kioskName, style: text.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                if (kiosk != null && kiosk.location.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on, color: colors.primaryText),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(kiosk.location, style: text.bodyLarge)),
                    ],
                  ),
                if (kiosk != null && kiosk.openTime != null && kiosk.closeTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Mở cửa ${kiosk.openTime}–${kiosk.closeTime}',
                      style: text.bodyMedium?.copyWith(color: colors.muted),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Mã nhận món: ${order.pickupCode}',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderTrackingViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Theo dõi đơn', closes: true, onBack: () => context.go(AppRoutes.home)),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn hàng…'),
        ViewError(:final message) => TestId(
          's07.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => EmptyView(
          message: message ?? 'Không tìm thấy đơn này.',
          actionLabel: 'Về trang chủ',
          onAction: () => context.go(AppRoutes.home),
        ),
        ViewData(:final data) => _Body(
          vm: vm,
          order: data,
          onCancel: () => _cancel(vm, data),
          onDirections: () => _directions(vm, data),
        ),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm, required this.order, required this.onCancel, required this.onDirections});

  final OrderTrackingViewModel vm;
  final Order order;
  final VoidCallback onCancel;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final cancelled = order.status == OrderStatus.cancelled;
    final showCode = !cancelled && order.status != OrderStatus.delivered;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      children: [
        TestId(
          's07.header',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mã nhận tại ${order.kioskName}', style: text.bodyMedium?.copyWith(color: colors.muted)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${order.orderCode}',
                          style: text.headlineMedium?.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
                        ),
                      ),
                      TestId(
                        's07.status',
                        child: StatusBadge(label: vm.badge, warning: cancelled),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 18, color: colors.muted),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(vm.timing, style: text.bodyMedium?.copyWith(color: colors.muted)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!cancelled) ...[
          const SizedBox(height: AppSpacing.md),
          TestId('s07.steps', child: _Steps(current: vm.stepIndex)),
        ],
        if (showCode) ...[
          const SizedBox(height: AppSpacing.md),
          TestId(
            's07.qr',
            child: ProfileSection(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    PickupQrCode(
                      data: order.qrPayload,
                      semanticLabel: 'Mã QR nhận món, mã số ${order.pickupCode.split('').join(' ')}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Quét tại đầu đọc kiosk để nhận món',
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text('Mã số: ${order.pickupCode}', style: text.bodyMedium?.copyWith(color: colors.muted)),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TestId(
          's07.items',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.items.map((i) => '${i.name} ×${i.quantity}').join(', '),
                    style: text.bodyMedium?.copyWith(color: colors.muted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (vm.paysAtCounter) ...[
                        Icon(Icons.payments_outlined, color: colors.primaryText),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Text(vm.paymentLine, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showCode) ...[
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: TestId(
              's07.directions',
              child: AppButton(label: 'Chỉ đường tới kiosk', onPressed: onDirections),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (showCode)
          ListenableBuilder(
            listenable: vm.cancel,
            builder: (context, _) => QuickActionRow(
              actions: [
                QuickAction(
                  label: 'Sửa đơn',
                  icon: Icons.edit_outlined,
                  testId: 's07.edit',
                  onPressed: vm.canChange ? () => context.push(AppRoutes.orderEditOf(order.id)) : null,
                ),
                QuickAction(
                  label: vm.cancel.running ? 'Đang huỷ…' : 'Huỷ đơn',
                  icon: Icons.cancel_outlined,
                  tone: QuickActionTone.destructive,
                  testId: 's07.cancel',
                  onPressed: vm.canChange && !vm.cancel.running ? onCancel : null,
                ),
                QuickAction(
                  label: 'Về trang chủ',
                  icon: Icons.home_outlined,
                  testId: 's07.home',
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          )
        else
          TestId(
            's07.home',
            child: AppButton(
              label: 'Về trang chủ',
              icon: Icons.home_outlined,
              variant: AppButtonVariant.secondary,
              large: true,
              onPressed: () => context.go(AppRoutes.home),
            ),
          ),
        if (showCode && !vm.canChange) ...[
          const SizedBox(height: AppSpacing.xs),
          TestId(
            's07.locked',
            child: Text(
              'Bếp đã nhận đơn nên không sửa hay huỷ được nữa.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.muted),
            ),
          ),
        ],
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    const steps = OrderTrackingViewModel.steps;
    return Semantics(
      label: 'Bước ${current + 1} trên ${steps.length}: ${steps[current]}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i == 0 ? Colors.transparent : (i <= current ? scheme.primary : colors.border),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < current ? scheme.primary : scheme.surface,
                          border: Border.all(color: i <= current ? scheme.primary : colors.borderInput, width: 2),
                        ),
                        child: i < current
                            ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                            : Text(
                                '${i + 1}',
                                style: text.labelLarge?.copyWith(
                                  color: i == current ? colors.primaryText : colors.muted,
                                ),
                              ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i == steps.length - 1
                              ? Colors.transparent
                              : (i < current ? scheme.primary : colors.border),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    steps[i],
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: i == current ? FontWeight.w800 : FontWeight.w400,
                      color: i == current ? colors.primaryText : colors.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
