import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/menu/view_models/menu_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _flight = CartFlight();
  late final _search = TextEditingController(text: context.read<MenuViewModel>().query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters(MenuViewModel vm) {
    _search.clear();
    vm.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MenuViewModel>();
    const gutter = EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding);

    return Scaffold(
      floatingActionButton: CartFab(
        flight: _flight,
        count: vm.cartCount,
        onPressed: () => context.push(AppRoutes.cart),
        testId: 's03.cart',
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: gutter.copyWith(top: AppSpacing.xs),
              child: _Header(vm: vm),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: gutter,
              child: TestId(
                's03.search',
                child: AppSearchField(hint: 'Tìm món nhanh...', controller: _search, onChanged: vm.search),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: gutter,
              child: Row(
                children: [
                  for (final filter in MenuFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: TestId(
                        's03.filter.${filter.name}',
                        child: AppChip(
                          label: filter.label,
                          selected: vm.filter == filter,
                          onSelected: (_) => vm.choose(filter),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _MenuList(vm: vm, flight: _flight, onClearFilters: () => _clearFilters(vm)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.vm});

  final MenuViewModel vm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final kiosk = vm.kiosk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Thực đơn', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (kiosk != null)
          TestId(
            's03.kiosk',
            child: Semantics(
              button: true,
              label: '${kiosk.name}. ${vm.kioskStatus ?? ''}. Chạm để đổi kiosk',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => context.push(AppRoutes.kiosks),
                borderRadius: BorderRadius.circular(AppRadius.input),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppA11y.minTouchTarget),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 18, color: colors.primaryText),
                      const SizedBox(width: AppSpacing.xxs),
                      Flexible(
                        child: Text(
                          '${kiosk.name} · ${vm.kioskStatus ?? ''}',
                          style: text.bodyMedium?.copyWith(color: colors.muted),
                          // Two lines, so the status stays readable at 200 % text (manual session 10/11).
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.expand_more, size: 20, color: colors.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MenuList extends StatelessWidget {
  const _MenuList({required this.vm, required this.flight, required this.onClearFilters});

  final MenuViewModel vm;
  final CartFlight flight;
  final VoidCallback onClearFilters;

  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.screenPadding,
    AppSpacing.sm,
    AppSpacing.screenPadding,
    cartFabClearance,
  );

  @override
  Widget build(BuildContext context) {
    return switch (vm.state) {
      ViewLoading<List<MenuItem>>() => ListView(padding: _padding, children: const [SkeletonList(count: 4)]),
      ViewEmpty<List<MenuItem>>(:final message) => TestId(
        's03.empty',
        child: vm.filtering
            ? EmptyView(
                message: message ?? MenuViewModel.noMatchMessage,
                icon: Icons.search_off,
                actionLabel: 'Xoá bộ lọc',
                onAction: onClearFilters,
              )
            : EmptyView(
                message: message ?? MenuViewModel.emptyMenuMessage,
                icon: Icons.storefront_outlined,
                actionLabel: 'Đổi kiosk',
                onAction: () => context.push(AppRoutes.kiosks),
              ),
      ),
      ViewError<List<MenuItem>>(:final message) => TestId(
        's03.retry',
        child: ErrorView(message: message, onRetry: vm.load),
      ),
      ViewData<List<MenuItem>>(:final data) => ListView.separated(
        padding: _padding,
        itemCount: data.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final item = data[index];
          return FoodCard(
            item: item,
            // A sold-out card opens S22 (when it is back, what to order instead); a card in stock opens S04.
            onTap: () =>
                context.push(item.soldOut ? AppRoutes.menuAlternativesOf(item.id) : AppRoutes.menuItemOf(item.id)),
            onAdd: item.soldOut
                ? null
                : () => flight.add(
                    context,
                    item: item,
                    blocked: vm.blocksAdd(item),
                    write: () => vm.addToCart.execute(item),
                  ),
            quantity: vm.quantityOf(item.id),
            onIncrement: vm.canIncrease(item.id)
                ? () => flight.change(context, () => vm.changeQuantity(item, 1))
                : null,
            onDecrement: () => flight.change(context, () => vm.changeQuantity(item, -1)),
            imageKey: flight.imageKeyOf(item.id),
            testId: 's03.item.${item.id}',
          );
        },
      ),
    };
  }
}
