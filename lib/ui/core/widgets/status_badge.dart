import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: warning ? scheme.errorContainer : colors.selected,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: warning ? scheme.error : scheme.primary),
      ),
      child: Text(label, style: text.labelLarge?.copyWith(color: warning ? scheme.error : colors.primaryText)),
    );
  }
}
