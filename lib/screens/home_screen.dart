import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/widgets.dart';

/// S02 Trang chủ: banner Combo Giờ Vàng (Remote Config) và danh sách món nhanh dưới 5 phút.
/// Màn chỉ vẽ theo `HomeViewModel`; logic lọc, giới hạn và ghi giỏ hàng nằm trong ViewModel.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const AppTopBar(title: 'Trang chủ'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vm.promoBannerEnabled)
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, 0),
              child: _PromoBanner(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.lg, AppSpacing.screenPadding, AppSpacing.sm),
            child: Semantics(header: true, child: Text('Món nhanh dưới 5 phút', style: text.titleLarge)),
          ),
          Expanded(
            child: ViewStateView<List<MenuItem>>(
              state: vm.state,
              onRetry: vm.load,
              builder: (context, items) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 0, AppSpacing.screenPadding, AppSpacing.xl),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return FoodCard(
                    item: item,
                    onTap: () => context.push('/menu/${item.id}'),
                    onAdd: item.soldOut ? null : () => _add(context, vm, item),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, HomeViewModel vm, MenuItem item) async {
    await vm.addToCart(item);
    if (!context.mounted) return;
    showAddedSnackbar(
      context,
      message: 'Đã thêm ${item.name} vào giỏ',
      onViewCart: () => context.push('/cart'),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Combo Giờ Vàng. Đặt trước, nhận ngay giờ ra chơi',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.selected,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt, color: colors.primaryText),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Combo Giờ Vàng', style: text.titleMedium?.copyWith(color: colors.primaryText)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Đặt trước, nhận ngay giờ ra chơi', style: text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
