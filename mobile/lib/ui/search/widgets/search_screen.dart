import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/menu/view_models/kiosk_menu.dart';
import 'package:breakbite/ui/search/view_models/search_view_model.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S28 and S28-EMPTY: search by name across the menu of the selected kiosk. Type to filter; a word with no
/// match shows suggestions to try instead.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _flight = CartFlight();
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The customer tapped the search box of Home to get here: the cursor goes in at once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _suggest(SearchViewModel vm, String word) {
    _controller.text = word;
    vm.searchNow(word);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: Icons.arrow_back,
          semanticLabel: 'Quay lại',
          onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.screenPadding),
          child: TestId(
            's28.search',
            child: AppSearchField(
              hint: 'Tìm món theo tên…',
              controller: _controller,
              focusNode: _focus,
              onChanged: vm.setQuery,
            ),
          ),
        ),
        toolbarHeight: 68,
      ),
      floatingActionButton: CartFab(
        flight: _flight,
        count: vm.cartCount,
        onPressed: () => context.push(AppRoutes.cart),
        testId: 's28.cart',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.xs),
            child: Row(
              children: [
                for (final filter in SearchFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: TestId(
                      's28.filter.${filter.name}',
                      child: AppChip(
                        label: filter.label,
                        selected: vm.filter == filter,
                        onSelected: (_) => vm.setFilter(filter),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: switch (vm.state) {
              ViewLoading() => const LoadingView(message: 'Đang tìm…'),
              ViewError(:final message) => TestId(
                's28.retry',
                child: ErrorView(message: message, onRetry: vm.retry),
              ),
              ViewEmpty(:final message) when message == KioskMenu.noKioskMessage => const TestId(
                's28.noKiosk',
                child: EmptyView(message: KioskMenu.noKioskMessage, icon: Icons.storefront_outlined),
              ),
              ViewEmpty(:final message) when vm.searching => TestId(
                's28.empty',
                child: _NoResults(
                  message: message ?? 'Không tìm thấy "${vm.query}"',
                  onSuggest: (w) => _suggest(vm, w),
                ),
              ),
              ViewEmpty() => _Hint(onSuggest: (w) => _suggest(vm, w)),
              ViewData(:final data) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  0,
                  AppSpacing.screenPadding,
                  cartFabClearance,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: TestId(
                      's28.count',
                      child: Text(
                        '${data.length} kết quả cho "${vm.query}"',
                        style: text.bodyMedium?.copyWith(color: colors.muted),
                      ),
                    ),
                  ),
                  for (final item in data)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: FoodCard(
                        item: item,
                        onTap: () => context.push(
                          item.soldOut ? AppRoutes.menuAlternativesOf(item.id) : AppRoutes.menuItemOf(item.id),
                        ),
                        onAdd: () => _flight.add(
                          context,
                          item: item,
                          blocked: vm.blocksAdd(item),
                          write: () => vm.addToCart(item),
                        ),
                        quantity: vm.quantityOf(item),
                        onIncrement: vm.canIncrease(item)
                            ? () => _flight.change(context, () => vm.changeQuantity(item, 1))
                            : null,
                        onDecrement: () => _flight.change(context, () => vm.changeQuantity(item, -1)),
                        imageKey: _flight.imageKeyOf(item.id),
                        kioskClosed: vm.closed,
                        testId: 's28.item.${item.id}',
                      ),
                    ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Before anything is typed: a prompt and the suggestions.
class _Hint extends StatelessWidget {
  const _Hint({required this.onSuggest});

  final ValueChanged<String> onSuggest;

  @override
  Widget build(BuildContext context) => TestId(
    's28.hint',
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gõ tên món để tìm. Không cần gõ dấu.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          _Suggestions(onSuggest: onSuggest),
        ],
      ),
    ),
  );
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.message, required this.onSuggest});

  final String message;
  final ValueChanged<String> onSuggest;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Icon(Icons.search_off, size: 64, color: colors.muted, semanticLabel: 'Không có kết quả'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Thử từ khoá khác hoặc xem các món bán chạy.',
          style: text.bodyMedium?.copyWith(color: colors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        _Suggestions(onSuggest: onSuggest),
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onSuggest});

  final ValueChanged<String> onSuggest;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text('Gợi ý', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final word in SearchViewModel.suggestions)
            TestId(
              's28.suggest.${slugify(word)}',
              child: AppChip(label: word, selected: false, onSelected: (_) => onSuggest(word)),
            ),
        ],
      ),
    ],
  );
}
