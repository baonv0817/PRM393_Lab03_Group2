import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/ui/home/view_models/home_view_model.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';

/// S02 Trang chủ: đầu trang cho kiosk (trạng thái chờ, thông báo, giỏ hàng), ô tìm kiếm, một
/// banner gọn (Remote Config), món nhanh có ảnh và nút "Đặt lại" khi đã có đơn.
///
/// So với Figma v2 đã bỏ chip loại món (lọc món là việc của tab Thực đơn, chip trên Trang chủ chỉ
/// lọc danh sách ngắn gây khó hiểu) và nút "Đặt ngay" trong banner (cả banner đã bấm được).
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.xs, AppSpacing.screenPadding, AppSpacing.lg),
          children: [
            _Header(vm: vm),
            const SizedBox(height: AppSpacing.sm),
            AppSearchField(hint: 'Tìm Tacos, Mì trộn, Đồ uống...', onTap: () => context.push(AppRoutes.search)),
            if (vm.promoBannerEnabled) ...[
              const SizedBox(height: AppSpacing.md),
              _PromoBanner(onTap: () => context.go(AppRoutes.menu)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Semantics(header: true, child: Text('Món nhanh · tối đa 5 phút', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(height: AppSpacing.sm),
            _QuickSection(vm: vm, onAdd: (item) => _add(context, vm, item)),
            if (vm.lastOrder case final order?) ...[
              const SizedBox(height: AppSpacing.xxs),
              _ReorderCard(order: order, onTap: () => _reorder(context, vm)),
            ],
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
      onViewCart: () => context.push(AppRoutes.cart),
    );
  }

  Future<void> _reorder(BuildContext context, HomeViewModel vm) async {
    final count = await vm.reorderLast();
    if (!context.mounted || count == 0) return;
    showAddedSnackbar(
      context,
      message: 'Đã thêm $count món của đơn gần đây vào giỏ',
      onViewCart: () => context.push(AppRoutes.cart),
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
          onPressed: () => context.push(AppRoutes.notifications),
        ),
        AppBadgeIconButton(
          icon: Icons.shopping_cart,
          semanticLabel: cartLabel,
          count: vm.cartCount,
          onPressed: () => context.push(AppRoutes.cart),
        ),
      ],
    );
  }
}

/// Banner ưu đãi: hai dòng, cả khối bấm được (không có nút phụ).
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
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: FoodCard(
                  item: item,
                  onTap: () => context.push(AppRoutes.menuItemOf(item.id)),
                  onAdd: item.soldOut ? null : () => onAdd(item),
                ),
              ),
          ],
        ),
    };
  }
}

/// Đặt lại đơn gần nhất: chỉ hiện khi đã có đơn, kèm tóm tắt món và tổng tiền.
class _ReorderCard extends StatelessWidget {
  const _ReorderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

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
                        Text(_summary, style: text.bodyMedium?.copyWith(color: colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
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
