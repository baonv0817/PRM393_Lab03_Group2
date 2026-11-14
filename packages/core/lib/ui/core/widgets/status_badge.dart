import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/theme/order_stage.dart';
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.warning = false, this.stage});

  final String label;
  final bool warning;

  /// An order's stage: the badge takes its colour and icon, so "waiting", "being made", "ready", "picked up" and
  /// "cancelled" look different. Without it the badge is the brand colour, or red when [warning].
  final OrderStage? stage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final stage = this.stage;
    final foreground = stage?.color ?? (warning ? scheme.error : colors.primaryText);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: stage?.tint ?? (warning ? scheme.errorContainer : colors.selected),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: stage?.color ?? (warning ? scheme.error : scheme.primary)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stage != null) ...[Icon(stage.icon, size: 16, color: foreground), const SizedBox(width: AppSpacing.xxs)],
          Flexible(
            child: Text(label, style: text.labelLarge?.copyWith(color: foreground)),
          ),
        ],
      ),
    );
  }
}
