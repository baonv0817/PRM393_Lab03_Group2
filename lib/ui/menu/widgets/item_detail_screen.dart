import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/menu/view_models/item_detail_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemDetailViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Chi tiết món', onBack: () => context.pop()),
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
