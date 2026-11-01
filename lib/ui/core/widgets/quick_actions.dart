import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/test_id.dart';
import 'package:flutter/material.dart';

enum QuickActionTone { neutral, destructive }

class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = QuickActionTone.neutral,
    this.testId,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final QuickActionTone tone;
  final String? testId;
}

class QuickActionRow extends StatelessWidget {
  const QuickActionRow({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, indent: 12, endIndent: 12, color: colors.border),
              Expanded(child: _QuickActionItem(action: actions[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final enabled = action.onPressed != null;
    final destructive = action.tone == QuickActionTone.destructive;
    final tint = !enabled
        ? colors.border
        : destructive
        ? scheme.error
        : colors.primaryText;
    final background = !enabled
        ? colors.surfaceVariant
        : destructive
        ? scheme.errorContainer
        : colors.selected;
    final item = Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: action.onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xxs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                  child: Icon(action.icon, size: 20, color: tint),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: text.labelLarge?.copyWith(
                    color: enabled ? (destructive ? scheme.error : colors.primaryText) : colors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final id = action.testId;
    return id == null ? item : TestId(id, child: item);
  }
}
