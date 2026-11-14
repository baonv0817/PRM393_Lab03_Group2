import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:breakbite_core/ui/core/widgets/menu_image.dart';
import 'package:breakbite_core/ui/core/widgets/quantity_stepper.dart';
import 'package:breakbite_core/ui/core/widgets/test_id.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
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
    this.kioskClosed = false,
    this.reopenLabel,
  });

  final MenuItem item;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final Key? imageKey;
  final String? testId;

  /// S21: the kiosk takes no orders, so the card shows "Quán đóng" instead of the + button.
  final bool kioskClosed;

  /// Shown under the name of a card whose kiosk is closed, e.g. "Mở lại lúc 10:30".
  final String? reopenLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final dim = item.soldOut ? colors.muted : null;
    // A dish with options cannot be added or stepped from the list: which size or topping would it be? Its "+" opens
    // the item (S04), where the customer picks, and the stepper is left to the cart.
    final withOptions = item.hasOptions;
    final Widget action;
    if (item.soldOut) {
      action = Container(
        key: const ValueKey('soldOut'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text('Tạm hết', style: text.labelLarge?.copyWith(color: scheme.onError)),
      );
    } else if (kioskClosed) {
      action = Container(
        key: const ValueKey('kioskClosed'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: colors.border),
        ),
        child: Text('Quán đóng', style: text.labelLarge?.copyWith(color: colors.primaryText)),
      );
    } else if (quantity > 0 && !withOptions) {
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
          semanticLabel: withOptions ? 'Chọn tuỳ chọn cho ${item.name}' : 'Thêm ${item.name} vào giỏ',
          onPressed: withOptions ? onTap : onAdd,
          filled: true,
        ),
      );
    }
    final card = Semantics(
      label:
          '${item.name}, ${formatVnd(item.priceVnd)}${item.soldOut ? ', tạm hết' : ''}'
          '${withOptions ? ', có tuỳ chọn' : ''}'
          '${item.soldOut && item.availableAgainAt != null ? ', có lại lúc ${formatTime(item.availableAgainAt!)}' : ''}'
          '${!item.soldOut && kioskClosed ? ', quán đóng${reopenLabel == null ? '' : ', ${reopenLabel!.toLowerCase()}'}' : ''}'
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
                      if (item.soldOut && item.availableAgainAt != null)
                        Text(
                          'Có lại lúc ${formatTime(item.availableAgainAt!)}',
                          style: text.bodyMedium?.copyWith(color: colors.muted),
                        )
                      else if (kioskClosed && reopenLabel != null)
                        Text(reopenLabel!, style: text.bodyMedium?.copyWith(color: colors.muted))
                      else
                        Row(
                          children: [
                            Icon(
                              item.prepMinutes <= 5 ? Icons.bolt_rounded : Icons.schedule,
                              size: 16,
                              color: item.prepMinutes <= 5 ? colors.primaryText : colors.muted,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Flexible(
                              child: Text(
                                _subtitleOf(item, withOptions: withOptions),
                                style: text.bodyMedium?.copyWith(color: colors.muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatVnd(item.priceVnd),
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: dim ?? colors.primaryText,
                              ),
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

  static String _subtitleOf(MenuItem item, {required bool withOptions}) {
    final desc = item.description.trim();
    final showDesc = desc.isNotEmpty && desc.toLowerCase() != item.name.trim().toLowerCase();
    return [
      '${item.prepMinutes} phút',
      if (withOptions) 'Có tuỳ chọn',
      if (showDesc) desc,
    ].join(' · ');
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
