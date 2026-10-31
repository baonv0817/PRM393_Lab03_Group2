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

/// S02 Home: kiosk header (wait time, notifications, cart), search field, a compact banner (Remote
/// Config), quick items with photos and a Reorder card once there is an order.
///
/// Compared with Figma v2 the category chips are dropped (filtering belongs to the Menu tab; chips on
/// Home only filter a short list and confuse) and so is the banner button (the whole banner is tappable),
/// see deviation D06. The screen only draws `HomeViewModel`; filtering, limits and cart writes live there.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.xs,
            AppSpacing.screenPadding,
            AppSpacing.lg,
          ),
          children: [
            _Header(vm: vm),
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
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text('Món nhanh · tối đa 5 phút', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _QuickSection(vm: vm, onAdd: (item) => _add(context, vm, item)),
            if (vm.lastOrder case final order?) ...[
              const SizedBox(height: AppSpacing.xxs),
              TestId(
                's02.reorder',
                child: ListenableBuilder(
                  listenable: vm.reorderLast,
                  builder: (context, _) =>
                      _ReorderCard(order: order, onTap: vm.reorderLast.running ? null : () => _reorder(context, vm)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, HomeViewModel vm, MenuItem item) async {
    final result = await vm.addToCart.execute(item);
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        showAddedSnackbar(
          context,
          message: 'Đã thêm ${item.name} vào giỏ',
          onViewCart: () => context.push(AppRoutes.cart),
        );
      case Err(:final error):
        _showError(context, error.message);
    }
  }

  Future<void> _reorder(BuildContext context, HomeViewModel vm) async {
    final result = await vm.reorderLast.execute();
    if (!context.mounted || result == null) return;
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
        _showError(context, error.message);
    }
  }

  void _showError(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _Header extends StatelessWidget {
  const _Header({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final kiosk = vm.kiosk;
    final status = vm.kioskStatus;
    final cartLabel = vm.cartCount == 0 ? 'Giỏ hàng, trống' : 'Giỏ hàng, ${vm.cartCount} món';
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
                                    color: (kiosk?.open ?? false) ? colors.success : colors.muted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    status,
                                    style: text.bodyMedium?.copyWith(color: colors.muted),
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
        TestId(
          's02.cart',
          child: AppBadgeIconButton(
            icon: Icons.shopping_cart,
            semanticLabel: cartLabel,
            count: vm.cartCount,
            onPressed: () => context.push(AppRoutes.cart),
          ),
        ),
      ],
    );
  }
}

/// Promo banner: two lines, the whole block is tappable (no extra button).
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

/// Minimum height of the loading, empty and error area; it grows when the message needs more room
/// (narrow phones, large text).
const _stateArea = BoxConstraints(minHeight: 300);

class _QuickSection extends StatelessWidget {
  const _QuickSection({required this.vm, required this.onAdd});

  final HomeViewModel vm;
  final void Function(MenuItem item) onAdd;

  @override
  Widget build(BuildContext context) {
    return switch (vm.state) {
      ViewLoading<List<MenuItem>>() => ConstrainedBox(constraints: _stateArea, child: const LoadingView()),
      ViewEmpty<List<MenuItem>>(:final message) => ConstrainedBox(
        constraints: _stateArea,
        child: EmptyView(message: message ?? 'Chưa có món nhanh lúc này'),
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
                onAdd: item.soldOut ? null : () => onAdd(item),
                testId: 's02.item.${item.id}',
              ),
            ),
        ],
      ),
    };
  }
}

/// Reorder the latest order: shown only once there is an order, with the items and the total.
class _ReorderCard extends StatelessWidget {
  const _ReorderCard({required this.order, required this.onTap});

  final Order order;

  /// `null` while the reorder runs, which disables the card.
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
