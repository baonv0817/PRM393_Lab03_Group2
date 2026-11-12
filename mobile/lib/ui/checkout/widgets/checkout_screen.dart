import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/checkout/view_models/checkout_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
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

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  static String outcomeMessage(GatewayOutcome outcome) => switch (outcome) {
    GatewayOutcome.declined => 'Bạn đã từ chối giao dịch ở cổng thanh toán.',
    GatewayOutcome.expired => 'Giao dịch đã hết hạn trước khi được xác nhận.',
    GatewayOutcome.cancelled => 'Bạn đã rời cổng thanh toán trước khi xác nhận.',
  };

  Future<void> _confirm(BuildContext context, CheckoutViewModel vm) async {
    if (vm.needsGateway) {
      vm.openGateway();
      await context.push(AppRoutes.checkoutGateway, extra: vm);
      return;
    }
    final result = await vm.place.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok(:final value):
        context.go(AppRoutes.orderOf(value));
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CheckoutViewModel>();
    final failure = vm.failure;
    final total = formatVnd(vm.pricing.totalVnd);
    final buttonLabel = switch ((failure, vm.method)) {
      (null, _) => 'Xác nhận đặt đơn · $total',
      (_, PaymentMethod.cash) => 'Đặt đơn, trả tiền mặt tại kiosk',
      (_, final method) => 'Thử lại với ${paymentMethodLabel(method)}',
    };
    return Scaffold(
      appBar: AppTopBar(
        title: failure == null ? 'Thanh toán' : 'Thanh toán chưa thành công',
        onBack: () => context.pop(),
      ),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang chuẩn bị thanh toán…'),
        ViewError(:final message) => TestId(
          's06.retry',
          child: ErrorView(message: message, onRetry: vm.retry),
        ),
        ViewEmpty(:final message) => EmptyView(
          message: message ?? 'Giỏ hàng đang trống.',
          icon: Icons.shopping_cart_outlined,
          actionLabel: 'Về trang chủ',
          onAction: () => context.go(AppRoutes.home),
        ),
        ViewData() => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                children: [
                  if (failure == null) _AmountCard(vm: vm) else ...[_FailureCard(failure: failure), _KeptCard(vm: vm)],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    failure == null ? 'Chọn phương thức' : 'Chọn cách thanh toán khác',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final method in vm.methods) ...[
                    PaymentMethodTile(
                      testId: 's06.method.${method.name}',
                      method: method,
                      selected: vm.method == method,
                      onTap: () => vm.choose(method),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (vm.blocker case final message?)
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: vm.place,
              builder: (context, _) => BottomActionButton(
                label: buttonLabel,
                testId: 's06.confirm',
                loading: vm.place.running,
                onPressed: vm.canPlace ? () => _confirm(context, vm) : null,
              ),
            ),
            if (failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: TestId(
                  's06.backToCart',
                  child: TextButton(onPressed: () => context.pop(), child: const Text('Quay lại giỏ hàng')),
                ),
              ),
          ],
        ),
      },
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.vm});

  final CheckoutViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final discount = vm.pricing.discountVnd;
    return TestId(
      's06.amount',
      child: ProfileSection(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Số tiền thanh toán', style: text.bodyMedium?.copyWith(color: colors.muted)),
                  ),
                  if (discount > 0) ...[
                    Icon(Icons.local_offer, size: 18, color: colors.primaryText),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Đã giảm ${formatVnd(discount)}',
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                formatVnd(vm.pricing.totalVnd),
                style: text.headlineMedium?.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              Text(
                'Nhận tại ${vm.kiosk?.name ?? 'kiosk'} · ${vm.quote.value.itemCount} món',
                style: text.bodyMedium?.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure});

  final PaymentFailure failure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return TestId(
      's06.error',
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: scheme.error, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error, color: scheme.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thanh toán ${paymentMethodLabel(failure.method)} thất bại',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(CheckoutScreen.outcomeMessage(failure.outcome), style: text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeptCard extends StatelessWidget {
  const _KeptCard({required this.vm});

  final CheckoutViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final summary = vm.items.map((i) => '${i.name} ×${i.quantity}').join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: TestId(
        's06.kept',
        child: ProfileSection(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 20, color: colors.primaryText),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Giỏ hàng của bạn vẫn được giữ nguyên',
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(summary, style: text.bodyMedium?.copyWith(color: colors.muted)),
                Text(
                  'Tổng thanh toán: ${formatVnd(vm.pricing.totalVnd)}',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
