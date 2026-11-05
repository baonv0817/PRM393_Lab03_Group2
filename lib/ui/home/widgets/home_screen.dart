import 'dart:async';

import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/home/view_models/home_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _flight = CartFlight();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: CartFab(
        flight: _flight,
        count: vm.cartCount,
        onPressed: () => context.push(AppRoutes.cart),
        testId: 's02.cart',
      ),
      body: SafeArea(
        bottom: false,
        child: vm.kiosk == null && vm.state is ViewLoading<List<MenuItem>>
            ? const _HomeSkeleton()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.xs,
                  AppSpacing.screenPadding,
                  cartFabClearance,
                ),
                children: [
                  _Header(vm: vm),
                  // S21: while the kiosk takes no orders, Home only explains why and previews the menu (D29).
                  if (vm.closed) ...[
                    const SizedBox(height: AppSpacing.md),
                    TestId(
                      's21.closed',
                      child: _ClosedCard(vm: vm, onOtherKiosk: () => context.push(AppRoutes.kiosks)),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.sm),
                    TestId(
                      's02.search',
                      child: AppSearchField(
                        hint: 'Tìm Tacos, Mì trộn, Đồ uống...',
                        onTap: () => context.push(AppRoutes.search),
                      ),
                    ),
                    if (vm.promoBannerEnabled) ...[
                      const SizedBox(height: AppSpacing.md),
                      TestId('s02.promo', child: _PromoBanner(onTap: () => context.go(AppRoutes.menu))),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      vm.closed ? 'Xem trước thực đơn' : 'Món nhanh · tối đa 5 phút',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _QuickSection(
                    vm: vm,
                    imageKeyOf: _flight.imageKeyOf,
                    onAdd: (item) => _flight.add(
                      context,
                      item: item,
                      blocked: vm.blocksAdd(item),
                      write: () => vm.addToCart.execute(item),
                    ),
                    onChange: (item, delta) => _flight.change(context, () => vm.changeQuantity(item, delta)),
                  ),
                  if (vm.lastOrder case final order? when !vm.closed) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    TestId(
                      's02.reorder',
                      child: ListenableBuilder(
                        listenable: vm.reorderLast,
                        builder: (context, _) =>
                            _ReorderCard(order: order, onTap: vm.reorderLast.running ? null : () => _reorder(vm)),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _reorder(HomeViewModel vm) async {
    final result = await vm.reorderLast.execute();
    if (!mounted || result == null) return;
    switch (result) {
      case Ok(value: 0):
        break;
      case Ok(value: final count):
        showAddedSnackbar(
          context,
          message: 'Đã thêm $count món của đơn gần đây vào giỏ',
          onViewCart: () => context.push(AppRoutes.cart),
        );
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final kiosk = vm.kiosk;
    final status = vm.kioskStatus;
    final bellLabel = vm.unreadNotifications == 0 ? 'Thông báo' : 'Thông báo, ${vm.unreadNotifications} chưa đọc';

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Kiosk ${kiosk?.name ?? ''}. $status. Chạm để đổi kiosk',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => context.push(AppRoutes.kiosks),
              borderRadius: BorderRadius.circular(AppRadius.input),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppA11y.minTouchTarget),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.location_on, color: colors.primaryText, size: 26),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kiosk?.name ?? 'BreakBite',
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (status != null)
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: vm.closed ? scheme.error : colors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    status,
                                    style: vm.closed
                                        ? text.bodyMedium?.copyWith(color: scheme.error, fontWeight: FontWeight.w700)
                                        : text.bodyMedium?.copyWith(color: colors.muted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        TestId(
          's02.notifications',
          child: AppBadgeIconButton(
            icon: Icons.notifications,
            semanticLabel: bellLabel,
            showDot: vm.unreadNotifications > 0,
            onPressed: () => context.push(AppRoutes.notifications),
          ),
        ),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Combo Giờ Vàng, giảm 15 phần trăm. Giờ nghỉ giải lao 10 giờ 15 đến 10 giờ 30. Chạm để xem thực đơn',
      excludeSemantics: true,
      child: Material(
        color: colors.selected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: colors.selectedBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Combo Giờ Vàng –15%', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: AppSpacing.xxs),
                      Text('Giờ nghỉ giải lao 10:15–10:30', style: text.bodyMedium?.copyWith(color: colors.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.primaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosedCard extends StatelessWidget {
  const _ClosedCard({required this.vm, required this.onOtherKiosk});

  final HomeViewModel vm;
  final VoidCallback onOtherKiosk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.error, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(Icons.schedule, color: scheme.error, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(vm.closedTitle, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(vm.closedMessage, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          TestId(
            's21.otherKiosk',
            child: AppButton(label: 'Chọn kiosk khác', icon: Icons.storefront, onPressed: onOtherKiosk),
          ),
        ],
      ),
    );
  }
}

const _stateArea = BoxConstraints(minHeight: 300);

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screenPadding,
      AppSpacing.sm,
      AppSpacing.screenPadding,
      AppSpacing.md,
    ),
    children: const [
      SkeletonList(
        leading: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(widthFactor: 0.6, child: SkeletonBox(height: 16, radius: AppRadius.pill)),
                    SizedBox(height: AppSpacing.xs),
                    FractionallySizedBox(widthFactor: 0.45, child: SkeletonBox(height: 12, radius: AppRadius.pill)),
                  ],
                ),
              ),
              SkeletonBox(height: 40, circle: true),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 52),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 72, radius: AppRadius.card),
          SizedBox(height: AppSpacing.lg),
          FractionallySizedBox(
            widthFactor: 0.6,
            alignment: Alignment.centerLeft,
            child: SkeletonBox(height: 16, radius: AppRadius.pill),
          ),
          SizedBox(height: AppSpacing.sm),
        ],
      ),
    ],
  );
}

class _QuickSection extends StatelessWidget {
  const _QuickSection({required this.vm, required this.imageKeyOf, required this.onAdd, required this.onChange});

  final HomeViewModel vm;
  final GlobalKey Function(String itemId) imageKeyOf;
  final void Function(MenuItem item) onAdd;
  final void Function(MenuItem item, int delta) onChange;

  @override
  Widget build(BuildContext context) {
    return switch (vm.state) {
      ViewLoading<List<MenuItem>>() => const SkeletonList(),
      ViewEmpty<List<MenuItem>>(:final message) => ConstrainedBox(
        constraints: _stateArea,
        child: EmptyView(message: message ?? HomeViewModel.quickEmptyMessage),
      ),
      ViewError<List<MenuItem>>(:final message) => ConstrainedBox(
        constraints: _stateArea,
        child: ErrorView(message: message, onRetry: vm.load),
      ),
      ViewData<List<MenuItem>>(:final data) => Column(
        children: [
          for (final item in data)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FoodCard(
                item: item,
                onTap: () => context.push(AppRoutes.menuItemOf(item.id)),
                onAdd: item.soldOut || vm.closed ? null : () => onAdd(item),
                quantity: vm.quantityOf(item.id),
                onIncrement: vm.canIncrease(item.id) ? () => onChange(item, 1) : null,
                onDecrement: () => onChange(item, -1),
                imageKey: imageKeyOf(item.id),
                testId: '${vm.closed ? 's21' : 's02'}.item.${item.id}',
                kioskClosed: vm.closed,
                reopenLabel: vm.reopenLabel,
              ),
            ),
        ],
      ),
    };
  }
}

class _ReorderCard extends StatelessWidget {
  const _ReorderCard({required this.order, required this.onTap});

  final Order order;

  final VoidCallback? onTap;

  String get _summary {
    final first = order.items.isEmpty ? '' : order.items.first.name;
    final more = order.items.length > 1 ? ' + ${order.items.length - 1} món' : '';
    return '$first$more · ${formatVnd(order.totalVnd)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Đặt lại đơn gần đây: $_summary',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.refresh, color: colors.primaryText),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Đặt lại đơn gần đây', style: text.labelLarge),
                        Text(
                          _summary,
                          style: text.bodyMedium?.copyWith(color: colors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
