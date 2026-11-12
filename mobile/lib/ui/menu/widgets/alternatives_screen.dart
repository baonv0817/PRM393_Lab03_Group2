import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/menu/view_models/alternatives_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S22 Món tạm hết: the sold-out item, when it is back, and in-stock items that can take its place.
class AlternativesScreen extends StatefulWidget {
  const AlternativesScreen({super.key});

  @override
  State<AlternativesScreen> createState() => _AlternativesScreenState();
}

class _AlternativesScreenState extends State<AlternativesScreen> {
  final _flight = CartFlight();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AlternativesViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: vm.title, onBack: () => context.pop()),
      floatingActionButton: CartFab(
        flight: _flight,
        count: vm.cartCount,
        onPressed: () => context.push(AppRoutes.cart),
        testId: 's22.cart',
      ),
      body: switch (vm.state) {
        ViewLoading<AlternativesData>() => const LoadingView(),
        ViewEmpty<AlternativesData>(:final message) => TestId(
          's22.empty',
          child: EmptyView(
            message: message ?? AlternativesViewModel.itemGoneMessage,
            icon: Icons.no_food_outlined,
            actionLabel: 'Về thực đơn',
            onAction: () => context.go(AppRoutes.menu),
          ),
        ),
        ViewError<AlternativesData>(:final message) => TestId(
          's22.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewData<AlternativesData>(:final data) => _Body(vm: vm, data: data, flight: _flight),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm, required this.data, required this.flight});

  final AlternativesViewModel vm;
  final AlternativesData data;
  final CartFlight flight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final item = data.item;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.xs,
        AppSpacing.screenPadding,
        cartFabClearance,
      ),
      children: [
        _ItemCard(vm: vm, item: item, flight: flight, onOpen: () => context.push(AppRoutes.menuItemOf(item.id))),
        const SizedBox(height: AppSpacing.xs),
        TestId('s22.availability', child: _AvailabilityBar(item: item)),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text('Gợi ý thay thế còn hàng', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (data.suggestions.isEmpty)
          TestId('s22.noSuggestions', child: _NoSuggestions(onMenu: () => context.go(AppRoutes.menu)))
        else
          for (final suggestion in data.suggestions) ...[
            _ItemCard(
              vm: vm,
              item: suggestion,
              flight: flight,
              testId: 's22.alt.${suggestion.id}',
              onOpen: () => context.push(AppRoutes.menuItemOf(suggestion.id)),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
      ],
    );
  }
}

/// One item as a [FoodCard]. The sold-out item shows "Tạm hết" instead of the add button; when it is back it is
/// an ordinary card.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.vm, required this.item, required this.flight, required this.onOpen, this.testId});

  final AlternativesViewModel vm;
  final MenuItem item;
  final CartFlight flight;
  final VoidCallback onOpen;
  final String? testId;

  @override
  Widget build(BuildContext context) {
    return FoodCard(
      item: item,
      onTap: onOpen,
      onAdd: () =>
          flight.add(context, item: item, blocked: vm.blocksAdd(item), write: () => vm.addToCart.execute(item)),
      quantity: vm.quantityOf(item.id),
      onIncrement: vm.canIncrease(item.id) ? () => flight.change(context, () => vm.changeQuantity(item, 1)) : null,
      onDecrement: () => flight.change(context, () => vm.changeQuantity(item, -1)),
      imageKey: flight.imageKeyOf(item.id),
      testId: testId ?? 's22.item.${item.id}',
    );
  }
}

/// The tinted bar under the sold-out card: "Có lại lúc 10:30", or that the item is back.
class _AvailabilityBar extends StatelessWidget {
  const _AvailabilityBar({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final back = !item.soldOut;
    final foreground = back ? colors.success : colors.primaryText;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.selected,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: colors.selectedBorder),
        ),
        child: Row(
          children: [
            Icon(back ? Icons.check_circle_outline : Icons.schedule, size: 20, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                AlternativesViewModel.availabilityMessage(item),
                style: text.bodyMedium?.copyWith(color: foreground, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSuggestions extends StatelessWidget {
  const _NoSuggestions({required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AlternativesViewModel.noSuggestionsMessage, style: text.bodyMedium?.copyWith(color: colors.muted)),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Xem thực đơn', variant: AppButtonVariant.secondary, onPressed: onMenu),
      ],
    );
  }
}
