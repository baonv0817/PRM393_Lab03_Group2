import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../viewmodels/home_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/widgets.dart';

/// S02 Trang chủ theo Figma v2: header kiosk (trạng thái, thông báo, giỏ), ô tìm kiếm, banner
/// Combo Giờ Vàng (Remote Config), chip loại món, danh sách món nhanh và nút "Đặt lại".
/// Màn chỉ vẽ theo `HomeViewModel`; logic lọc, giới hạn và ghi giỏ hàng nằm trong ViewModel.
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.sm, AppSpacing.screenPadding, AppSpacing.xl),
          children: [
            _Header(vm: vm),
            const SizedBox(height: AppSpacing.md),
            AppSearchField(hint: 'Tìm Tacos, Mì trộn, Đồ uống...', onTap: () => context.push('/search')),
            if (vm.promoBannerEnabled) ...[
              const SizedBox(height: AppSpacing.lg),
              _PromoBanner(onOrderNow: () => context.go('/menu')),
            ],
            const SizedBox(height: AppSpacing.lg),
            _CategoryChips(vm: vm),
            const SizedBox(height: AppSpacing.lg),
            Semantics(header: true, child: Text('Món nhanh dưới 5 phút', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(height: AppSpacing.md),
            _QuickSection(vm: vm, onAdd: (item) => _add(context, vm, item)),
            const SizedBox(height: AppSpacing.xs),
            _ReorderRow(onTap: () => context.go('/orders')),
          ],
        ),
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
              onTap: () => context.push('/kiosks'),
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
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kiosk?.name ?? 'BreakBite', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (status != null)
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: (kiosk?.open ?? false) ? colors.success : colors.muted, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Flexible(child: Text(status, style: text.bodyMedium?.copyWith(color: colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
        AppBadgeIconButton(
          icon: Icons.notifications,
          semanticLabel: bellLabel,
          showDot: vm.unreadNotifications > 0,
          onPressed: () => context.push('/notifications'),
        ),
        AppBadgeIconButton(
          icon: Icons.shopping_cart,
          semanticLabel: cartLabel,
          count: vm.cartCount,
          onPressed: () => context.push('/cart'),
        ),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onOrderNow});

  final VoidCallback onOrderNow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.selected,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.selectedBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Combo Giờ Vàng –15%', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.xs),
                Text('Giờ nghỉ giải lao 10:15–10:30', style: text.bodyMedium?.copyWith(color: colors.muted)),
                AppButton(label: 'Đặt ngay', variant: AppButtonVariant.text, onPressed: onOrderNow),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Icon(Icons.sell, color: colors.primaryText, size: 32),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final categories = vm.categories;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final label = i == 0 ? 'Tất cả' : categories[i - 1];
          final value = i == 0 ? null : categories[i - 1];
          return Center(
            child: AppChip(label: label, selected: vm.selectedCategory == value, onSelected: (_) => vm.selectCategory(value)),
          );
        },
      ),
    );
  }
}

/// Chiều cao vùng hiện loading, rỗng, lỗi (đủ chứa biểu tượng, lời nhắn và nút Thử lại).
const double _stateHeight = 300;

class _QuickSection extends StatelessWidget {
  const _QuickSection({required this.vm, required this.onAdd});

  final HomeViewModel vm;
  final void Function(MenuItem item) onAdd;

  @override
  Widget build(BuildContext context) {
    return switch (vm.state) {
      ViewLoading<List<MenuItem>>() => const SizedBox(height: _stateHeight, child: LoadingView()),
      ViewEmpty<List<MenuItem>>(:final message) => SizedBox(height: _stateHeight, child: EmptyView(message: message ?? 'Chưa có món nhanh lúc này')),
      ViewError<List<MenuItem>>(:final message) => SizedBox(height: _stateHeight, child: ErrorView(message: message, onRetry: vm.load)),
      ViewData<List<MenuItem>>(:final data) => Column(
          children: [
            for (final item in data)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: FoodCard(
                  item: item,
                  onTap: () => context.push('/menu/${item.id}'),
                  onAdd: item.soldOut ? null : () => onAdd(item),
                ),
              ),
          ],
        ),
    };
  }
}

class _ReorderRow extends StatelessWidget {
  const _ReorderRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Đặt lại đơn gần đây',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.refresh, color: colors.primaryText),
                  const SizedBox(width: AppSpacing.md),
                  Text('Đặt lại đơn gần đây', style: text.labelLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
