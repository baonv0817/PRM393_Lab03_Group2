import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/menu/view_models/item_detail_view_model.dart';
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

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemDetailViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: 'Chi tiết món',
        onBack: () => context.pop(),
        actions: [
          if (vm.canFavorite)
            TestId(
              's04.favorite',
              child: AppIconButton(
                icon: vm.isFavorite ? Icons.favorite : Icons.favorite_border,
                semanticLabel: vm.isFavorite ? 'Bỏ khỏi món yêu thích' : 'Thêm vào món yêu thích',
                onPressed: () async {
                  final result = await vm.toggleFavorite();
                  if (context.mounted) showResultError(context, result);
                },
              ),
            ),
        ],
      ),
      body: switch (vm.state) {
        ViewLoading<MenuItem>() => const LoadingView(),
        ViewEmpty<MenuItem>(:final message) => TestId(
          's04.empty',
          child: EmptyView(
            message: message ?? 'Không tìm thấy món.',
            icon: Icons.no_food_outlined,
            actionLabel: 'Về thực đơn',
            onAction: () => context.go(AppRoutes.menu),
          ),
        ),
        ViewError<MenuItem>(:final message) => TestId(
          's04.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewData<MenuItem>(:final data) => _Detail(vm: vm, item: data),
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.vm, required this.item});

  final ItemDetailViewModel vm;
  final MenuItem item;

  Future<void> _add(BuildContext context) async {
    final router = GoRouter.of(context);
    final quantity = vm.quantity;
    final result = await vm.add.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        showAddedSnackbar(
          context,
          message: 'Đã thêm $quantity × ${item.name} vào giỏ',
          onViewCart: () => router.push(AppRoutes.cart),
        );
        if (router.canPop()) router.pop();
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final blocker = vm.blocker;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.xs,
              AppSpacing.screenPadding,
              AppSpacing.lg,
            ),
            children: [
              LayoutBuilder(
                builder: (context, constraints) =>
                    MenuItemImage(imageUrl: item.imageUrl, size: constraints.maxWidth, height: 180),
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                child: Text(item.name, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: colors.muted),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text('${item.prepMinutes} phút', style: text.bodyMedium?.copyWith(color: colors.muted)),
                  ),
                  Text(
                    formatVnd(item.priceVnd),
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: colors.primaryText),
                  ),
                ],
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(item.description, style: text.bodyMedium),
              ],
              for (final group in item.optionGroups) ...[
                const SizedBox(height: AppSpacing.md),
                _OptionGroupCard(vm: vm, group: group),
              ],
              if (vm.inCart > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                TestId(
                  's04.inCart',
                  child: Text(
                    'Đã có ${vm.inCart} phần trong giỏ',
                    style: text.bodyMedium?.copyWith(color: colors.success, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Ghi chú cho bếp', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xs),
              TestId(
                's04.note',
                child: TextFormField(
                  initialValue: vm.note,
                  onChanged: vm.setNote,
                  maxLength: ItemDetailViewModel.maxNoteLength,
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'Ví dụ: không hành tây, ít cay'),
                ),
              ),
              if (blocker != null) ...[
                const SizedBox(height: AppSpacing.xs),
                TestId(
                  's04.blocker',
                  child: Semantics(
                    liveRegion: true,
                    child: Text(blocker, style: text.bodyMedium?.copyWith(color: scheme.error)),
                  ),
                ),
              ] else if (vm.optionsProblem case final problem?) ...[
                const SizedBox(height: AppSpacing.xs),
                TestId(
                  's04.optionsProblem',
                  child: Semantics(
                    liveRegion: true,
                    child: Text(problem, style: text.bodyMedium?.copyWith(color: scheme.error)),
                  ),
                ),
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
                AppSpacing.screenPadding,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Số lượng', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      QuantityStepper(
                        name: item.name,
                        quantity: vm.quantity,
                        removesAtOne: false,
                        onIncrement: vm.canIncrease ? () => vm.changeQuantity(1) : null,
                        onDecrement: vm.canDecrease ? () => vm.changeQuantity(-1) : null,
                        testId: 's04.quantity',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: ListenableBuilder(
                      listenable: vm.add,
                      builder: (context, _) => TestId(
                        's04.add',
                        child: AppButton(
                          label: vm.addLabel,
                          loading: vm.add.running,
                          onPressed: vm.canAdd ? () => _add(context) : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One group of options (size, topping): its name and rule on top, then a row per choice with its extra price.
/// A group that takes one choice shows round buttons, a group that takes several shows boxes.
class _OptionGroupCard extends StatelessWidget {
  const _OptionGroupCard({required this.vm, required this.group});

  final ItemDetailViewModel vm;
  final OptionGroup group;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final picked = vm.pickedIn(group.id);
    final full = group.multiple && picked.length >= group.maxChoices;
    return TestId(
      's04.group.${group.id}',
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.xxs),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(group.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  if (group.required) const StatusBadge(label: 'Bắt buộc', warning: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(group.hint, style: text.bodySmall?.copyWith(color: colors.muted)),
            ),
            for (final choice in group.choices)
              _ChoiceRow(
                id: 's04.opt.${group.id}.${choice.id}',
                choice: choice,
                multiple: group.multiple,
                selected: picked.contains(choice.id),
                enabled: picked.contains(choice.id) || !full,
                onTap: () => vm.pick(group, choice.id),
              ),
            const SizedBox(height: AppSpacing.xxs),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.id,
    required this.choice,
    required this.multiple,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String id;
  final OptionChoice choice;
  final bool multiple;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final icon = multiple
        ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
        : (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked);
    final extra = choice.extraVnd > 0 ? '+${formatVnd(choice.extraVnd)}' : 'Miễn phí';
    return TestId(
      id,
      child: Semantics(
        inMutuallyExclusiveGroup: !multiple,
        checked: selected,
        enabled: enabled,
        label: '${choice.name}, ${choice.extraVnd > 0 ? 'thêm ${formatVnd(choice.extraVnd)}' : 'không tính thêm'}',
        excludeSemantics: true,
        onTap: enabled ? onTap : null,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppA11y.minTouchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  Icon(icon, color: selected ? scheme.primary : (enabled ? colors.muted : colors.border)),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(choice.name, style: text.bodyLarge?.copyWith(color: enabled ? null : colors.muted)),
                  ),
                  Text(extra, style: text.bodyMedium?.copyWith(color: colors.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
