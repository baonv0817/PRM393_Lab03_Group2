import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/buttons.dart';
import 'package:breakbite/ui/core/widgets/menu_image.dart';
import 'package:breakbite/utils/format.dart';
import 'package:flutter/material.dart';

/// Lab 2 Card/Food: dish, drink, sold out.
class FoodCard extends StatelessWidget {
  const FoodCard({super.key, required this.item, required this.onTap, required this.onAdd});

  final MenuItem item;
  final VoidCallback onTap;

  /// `null` when sold out.
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
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                // Dish photo; if missing, MenuItemImage shows the soft logo.
                MenuItemImage(imageUrl: item.imageUrl, size: 80),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: dim),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: colors.muted),
                          const SizedBox(width: AppSpacing.xxs),
                          Text('${item.prepMinutes} phút', style: text.bodyMedium?.copyWith(color: colors.muted)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        formatVnd(item.priceVnd),
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: dim),
                      ),
                    ],
                  ),
                ),
                if (item.soldOut)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                    decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: Text('Tạm hết', style: text.labelLarge?.copyWith(color: scheme.onError)),
                  )
                else
                  AppIconButton(
                    icon: Icons.add,
                    semanticLabel: 'Thêm ${item.name} vào giỏ',
                    onPressed: onAdd,
                    filled: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lab 2 AppBar: title, 48 × 48 Back button.
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
      leading: onBack == null
          ? null
          : AppIconButton(icon: Icons.arrow_back, semanticLabel: 'Quay lại', onPressed: onBack),
      actions: actions,
    );
  }
}

class AppNavTab {
  const AppNavTab({required this.label, required this.icon});

  final String label;

  /// Filled icon (Figma uses filled icons for both selected and unselected tabs).
  final IconData icon;
}

/// Lab 2 4-tab NavBar (shared by customer and seller).
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.tabs, required this.selectedIndex, required this.onSelected});

  final List<AppNavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.appColors.border)),
      ),
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

/// Lab 2 confirmation dialog (cancel order, reject order…). Returns `true` when confirmed.
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
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
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

/// "Added to cart" notice with a View cart button (S02-ADDED, S03-ADDED).
void showAddedSnackbar(BuildContext context, {required String message, required VoidCallback onViewCart}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Xem giỏ',
          textColor: Theme.of(context).colorScheme.primary,
          onPressed: onViewCart,
        ),
      ),
    );
}
