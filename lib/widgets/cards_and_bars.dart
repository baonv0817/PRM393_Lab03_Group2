import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../utils/format.dart';
import 'buttons.dart';
import 'menu_image.dart';

/// Card/Food của Lab 2: món, đồ uống, hết hàng.
class FoodCard extends StatelessWidget {
  const FoodCard({super.key, required this.item, required this.onTap, required this.onAdd});

  final MenuItem item;
  final VoidCallback onTap;

  /// `null` khi hết hàng.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final dim = item.soldOut ? colors.muted : null;
    return Semantics(
      label: '${item.name}, ${formatVnd(item.priceVnd)}${item.soldOut ? ', tạm hết' : ''}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Ảnh món; thiếu ảnh thì MenuItemImage hiện logo bản nhạt.
                MenuItemImage(imageUrl: item.imageUrl, size: 80),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: dim), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: colors.muted),
                          const SizedBox(width: AppSpacing.xs),
                          Text('${item.prepMinutes} phút', style: text.bodyMedium?.copyWith(color: colors.muted)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(formatVnd(item.priceVnd), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: dim)),
                    ],
                  ),
                ),
                if (item.soldOut)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text('Tạm hết', style: text.labelLarge?.copyWith(color: scheme.onError)),
                  )
                else
                  AppIconButton(icon: Icons.add, semanticLabel: 'Thêm ${item.name} vào giỏ', onPressed: onAdd, filled: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// AppBar của Lab 2: tiêu đề, nút Back 48 × 48.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, this.onBack, this.actions});

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: false,
      leading: onBack == null ? null : AppIconButton(icon: Icons.arrow_back, semanticLabel: 'Quay lại', onPressed: onBack),
      actions: actions,
    );
  }
}

class AppNavTab {
  const AppNavTab({required this.label, required this.icon});

  final String label;

  /// Icon đặc (Figma dùng icon đặc cho cả tab đang chọn lẫn chưa chọn).
  final IconData icon;
}

/// NavBar 4 tab của Lab 2 (khách và người bán dùng chung).
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.tabs, required this.selectedIndex, required this.onSelected});

  final List<AppNavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.appColors.border))),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final t in tabs) NavigationDestination(icon: Icon(t.icon), label: t.label, tooltip: t.label),
        ],
      ),
    );
  }
}

/// Dialog xác nhận của Lab 2 (huỷ đơn, từ chối đơn…). Trả `true` khi xác nhận.
Future<bool?> showAppDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Giữ lại',
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      title: Text(title),
      content: Text(message),
      actions: [
        AppButton(label: cancelLabel, variant: AppButtonVariant.secondary, onPressed: () => Navigator.of(ctx).pop(false)),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(AppA11y.minTouchTarget, AppA11y.minTouchTarget),
            shape: const StadiumBorder(),
            backgroundColor: destructive ? Theme.of(ctx).colorScheme.error : Theme.of(ctx).colorScheme.primary,
            foregroundColor: destructive ? Theme.of(ctx).colorScheme.onError : Theme.of(ctx).colorScheme.onPrimary,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Thông báo "đã thêm vào giỏ" kèm nút Xem giỏ (S02-ADDED, S03-ADDED).
void showAddedSnackbar(BuildContext context, {required String message, required VoidCallback onViewCart}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Xem giỏ', textColor: Theme.of(context).colorScheme.primary, onPressed: onViewCart),
      ),
    );
}
