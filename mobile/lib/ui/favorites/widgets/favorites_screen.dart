import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/favorites/view_models/favorites_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S13: the dishes the customer hearted. Each row is today's menu item of the selected kiosk (with its price
/// and stock) and goes into the cart with one tap; a dish the kiosk does not sell is shown but cannot be added.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _flight = CartFlight();

  Future<void> _remove(FavoritesViewModel vm, Favorite favorite) async {
    final result = await vm.remove(favorite);
    if (!mounted) return;
    showResultError(context, result);
    if (!mounted) return;
    showAppMessage(context, 'Đã bỏ ${favorite.name} khỏi yêu thích.');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoritesViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: 'Món yêu thích',
        onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.profile),
      ),
      floatingActionButton: CartFab(
        flight: _flight,
        count: vm.cartCount,
        onPressed: () => context.push(AppRoutes.cart),
        testId: 's13.cart',
      ),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải món yêu thích…'),
        ViewError(:final message) => TestId(
          's13.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Filters(vm: vm),
            Expanded(
              child: TestId(
                's13.empty',
                child: EmptyView(
                  message: message ?? FavoritesViewModel.emptyMessage,
                  icon: Icons.favorite_border,
                  actionLabel: 'Xem thực đơn',
                  onAction: () => context.go(AppRoutes.menu),
                ),
              ),
            ),
          ],
        ),
        ViewData(:final data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Filters(vm: vm),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.xs,
                  AppSpacing.screenPadding,
                  cartFabClearance,
                ),
                children: [
                  for (final entry in data)
                    _Row(vm: vm, entry: entry, flight: _flight, onRemove: () => _remove(vm, entry.favorite)),
                ],
              ),
            ),
          ],
        ),
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.vm});

  final FavoritesViewModel vm;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.xs),
    child: Row(
      children: [
        for (final filter in FavoritesFilter.values)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: TestId(
              's13.filter.${filter.name}',
              child: AppChip(
                label: filter.label,
                selected: vm.filter == filter,
                onSelected: (_) => vm.setFilter(filter),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.vm, required this.entry, required this.flight, required this.onRemove});

  final FavoritesViewModel vm;
  final FavoriteEntry entry;
  final CartFlight flight;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final favorite = entry.favorite;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final Widget card = item == null
        ? TestId(
            's13.item.${favorite.dishId}',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(favorite.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text('Kiosk này chưa bán món này', style: text.bodyMedium?.copyWith(color: colors.muted)),
                          Text(
                            formatVnd(favorite.priceVnd),
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : FoodCard(
            item: item,
            onTap: () => context.push(AppRoutes.menuItemOf(item.id)),
            onAdd: () => flight.add(context, item: item, blocked: vm.blocksAdd(item), write: () => vm.addToCart(item)),
            quantity: vm.quantityOf(item),
            onIncrement: vm.canIncrease(item) ? () => flight.change(context, () => vm.changeQuantity(item, 1)) : null,
            onDecrement: () => flight.change(context, () => vm.changeQuantity(item, -1)),
            imageKey: flight.imageKeyOf(item.id),
            testId: 's13.item.${favorite.dishId}',
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card),
              TestId(
                's13.remove.${favorite.dishId}',
                child: AppIconButton(
                  icon: Icons.favorite,
                  semanticLabel: 'Bỏ ${favorite.name} khỏi yêu thích',
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
          if (entry.orderedTimes > 0)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: TestId(
                's13.times.${favorite.dishId}',
                child: Text('Đã đặt ${entry.orderedTimes} lần', style: text.bodyMedium?.copyWith(color: colors.muted)),
              ),
            ),
        ],
      ),
    );
  }
}
