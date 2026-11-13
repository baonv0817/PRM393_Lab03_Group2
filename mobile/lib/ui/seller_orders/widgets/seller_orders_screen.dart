import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_orders_view_model.dart';
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

/// K02 and K02-EMPTY: the queue of the kiosk in three tabs. A card opens the order (K03, K04 or K06 depending
/// on where it is); "Nhận đơn" starts a new order from the list.
class SellerOrdersScreen extends StatelessWidget {
  const SellerOrdersScreen({super.key});

  Future<void> _accept(BuildContext context, SellerOrdersViewModel vm, Order order) async {
    final result = await vm.accept(order);
    if (!context.mounted) return;
    if (result case Err(:final error)) showAppMessage(context, error.message);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellerOrdersViewModel>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppTopBar(
        title: 'Đơn hôm nay',
        actions: [
          TestId(
            'k02.incidents',
            child: AppBadgeIconButton(
              icon: Icons.notifications,
              semanticLabel: vm.openIncidents == 0
                  ? 'Sự cố từ khách'
                  : 'Sự cố từ khách, ${vm.openIncidents} chưa xử lý',
              showDot: vm.openIncidents > 0,
              onPressed: () => context.push(AppRoutes.sellerIncidents),
            ),
          ),
        ],
      ),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn…'),
        ViewError(:final message) => TestId(
          'k02.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'k02.empty',
          child: EmptyView(message: message ?? SellerOrdersViewModel.noKioskMessage, icon: Icons.storefront_outlined),
        ),
        ViewData() => Column(
          children: [
            if (vm.statusLine.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.xs,
                  AppSpacing.screenPadding,
                  0,
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: vm.acceptsOrders ? context.appColors.success : scheme.error),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: TestId(
                        'k02.status',
                        child: Text(
                          '${vm.acceptsOrders ? 'Đang nhận đơn' : 'Không nhận đơn'} · ${vm.kiosk?.name ?? ''}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.appColors.muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in SellerOrderTab.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: TestId(
                          'k02.tab.${tab.name}',
                          child: AppChip(
                            label: '${tab.label} (${vm.countOf(tab)})',
                            selected: vm.tab == tab,
                            onSelected: (_) => vm.select(tab),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: vm.visible.isEmpty
                  ? TestId(
                      'k02.emptyTab',
                      child: EmptyView(
                        message: vm.tab == SellerOrderTab.pending
                            ? 'Chưa có đơn mới. ${SellerOrdersViewModel.emptyMessage}'
                            : 'Chưa có đơn nào ở mục "${vm.tab.label}".',
                        icon: Icons.receipt_long_outlined,
                      ),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.screenPadding),
                          children: [
                            for (final order in vm.visible)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: SellerOrderCard(
                                  order: order,
                                  tab: vm.tab,
                                  busy: vm.busyOrderId == order.id,
                                  onAccept: () => _accept(context, vm, order),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      },
    );
  }
}

/// One order of K02: the number, when it is wanted, what is in it and how it is paid, so staff know which
/// orders to collect cash for.
class SellerOrderCard extends StatelessWidget {
  const SellerOrderCard({
    super.key,
    required this.order,
    required this.tab,
    required this.busy,
    required this.onAccept,
  });

  final Order order;
  final SellerOrderTab tab;
  final bool busy;
  final VoidCallback onAccept;

  String get _code => order.orderCode.isEmpty ? order.id : order.orderCode;

  String get _route => switch (tab) {
    SellerOrderTab.pending => AppRoutes.sellerOrderOf(order.id),
    SellerOrderTab.preparing => AppRoutes.sellerOrderPreparingOf(order.id),
    SellerOrderTab.ready => AppRoutes.sellerOrderDeliverOf(order.id),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unpaid = order.paymentStatus == PaymentStatus.unpaid;
    final pickup = order.pickupAt ?? order.readyBy;
    return TestId(
      'k02.order.${order.id}',
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(_route),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('#$_code', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    if (pickup != null) ...[
                      Icon(Icons.schedule, size: 18, color: colors.primaryText),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        'Nhận ${formatTime(pickup)}',
                        style: text.labelLarge?.copyWith(color: colors.primaryText, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  order.items.map((e) => '${e.displayName} ×${e.quantity}').join(', '),
                  style: text.bodyMedium?.copyWith(color: colors.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      unpaid ? Icons.payments_outlined : Icons.check,
                      size: 18,
                      color: unpaid ? colors.primaryText : colors.success,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        unpaid
                            ? 'Trả tại quầy ${formatVnd(order.totalVnd)}'
                            : 'Đã thanh toán ${paymentMethodLabel(order.paymentMethod)}',
                        style: text.bodyMedium?.copyWith(
                          color: unpaid ? colors.primaryText : colors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // The button spans the card, as in the Figma list (the column above aligns to the start).
                SizedBox(
                  width: double.infinity,
                  child: tab == SellerOrderTab.pending
                      ? TestId(
                          'k02.accept.${order.id}',
                          child: AppButton(
                            label: 'Nhận đơn',
                            variant: AppButtonVariant.secondary,
                            large: true,
                            loading: busy,
                            onPressed: onAccept,
                          ),
                        )
                      : TestId(
                          'k02.open.${order.id}',
                          child: AppButton(
                            label: tab == SellerOrderTab.preparing ? 'Xem đơn đang làm' : 'Giao món',
                            variant: AppButtonVariant.secondary,
                            large: true,
                            onPressed: () => context.push(_route),
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
