import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/test_id.dart';
import 'package:flutter/material.dart';

class SelectableCard extends StatelessWidget {
  const SelectableCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
    this.testId,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;
  final String? testId;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final card = Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.selected : scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: selected ? scheme.primary : colors.border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                Expanded(child: child),
                SizedBox.square(
                  dimension: AppA11y.minTouchTarget,
                  child: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : colors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return testId == null ? card : TestId(testId!, child: card);
  }
}
