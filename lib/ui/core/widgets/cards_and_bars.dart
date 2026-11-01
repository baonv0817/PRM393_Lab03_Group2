import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/buttons.dart';
import 'package:breakbite/ui/core/widgets/menu_image.dart';
import 'package:breakbite/ui/core/widgets/quantity_stepper.dart';
import 'package:breakbite/ui/core/widgets/test_id.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';

class FoodCard extends StatelessWidget {
  const FoodCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAdd,
    this.quantity = 0,
    this.onIncrement,
    this.onDecrement,
    this.imageKey,
    this.testId,
  });

  final MenuItem item;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final Key? imageKey;
  final String? testId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final dim = item.soldOut ? colors.muted : null;
    final Widget action;
    if (item.soldOut) {
      action = Container(
        key: const ValueKey('soldOut'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text('Tạm hết', style: text.labelLarge?.copyWith(color: scheme.onError)),
      );
    } else if (quantity > 0) {
      action = QuantityStepper(
        key: const ValueKey('stepper'),
        name: item.name,
        quantity: quantity,
        onIncrement: onIncrement,
        onDecrement: onDecrement,
        testId: testId,
      );
    } else {
      action = _withTestId(
        testId == null ? null : '$testId.add',
        AppIconButton(
          key: const ValueKey('add'),
          icon: Icons.add,
          semanticLabel: 'Thêm ${item.name} vào giỏ',
          onPressed: onAdd,
          filled: true,
        ),
      );
    }
    final card = Semantics(
      label:
          '${item.name}, ${formatVnd(item.priceVnd)}${item.soldOut ? ', tạm hết' : ''}'
          '${quantity > 0 ? ', $quantity trong giỏ' : ''}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                KeyedSubtree(
                  key: imageKey,
                  child: MenuItemImage(imageUrl: item.imageUrl, size: 80),
                ),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatVnd(item.priceVnd),
                              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: dim),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(scale: animation, alignment: Alignment.centerRight, child: child),
                            ),
                            layoutBuilder: (current, previous) =>
                                Stack(alignment: Alignment.centerRight, children: [...previous, ?current]),
                            child: action,
                          ),
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
    );
    return _withTestId(testId, card);
  }

  static Widget _withTestId(String? id, Widget child) => id == null ? child : TestId(id, child: child);
}

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, this.onBack, this.actions, this.closes = false});

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool closes;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: false,
      leading: onBack == null
          ? null
          : AppIconButton(
              icon: closes ? Icons.close : Icons.arrow_back,
              semanticLabel: closes ? 'Đóng' : 'Quay lại',
              onPressed: onBack,
            ),
      actions: actions,
    );
  }
}

class AppNavTab {
  const AppNavTab({required this.label, required this.icon});

  final String label;

  final IconData icon;
}

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

void showAddedSnackbar(BuildContext context, {required String message, required VoidCallback onViewCart}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        persist: false,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Xem giỏ',
          textColor: Theme.of(context).colorScheme.primary,
          onPressed: onViewCart,
        ),
      ),
    );
}

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showResultError(BuildContext context, Result<Object?>? result) {
  if (!context.mounted) return;
  if (result case Err(:final error)) showAppMessage(context, error.message);
}
