import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/motion.dart';
import 'package:flutter/material.dart';

/// The frame of a list on a system page: a white panel with a hairline border and the card radius, so rows read as
/// one list instead of text floating on the page. Rows that go past the bottom scroll inside it.
class ListPanel extends StatelessWidget {
  const ListPanel({super.key, required this.itemCount, required this.itemBuilder, this.firstRowsReveal = 10});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// How many rows at the top come in one after another when the list appears; the rest are simply there.
  final int firstRowsReveal;

  @override
  Widget build(BuildContext context) {
    // The panel is as tall as its rows (a short list does not leave a big empty frame) and scrolls inside when the
    // rows are more than the page can show.
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: context.appColors.border),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: itemCount,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final row = itemBuilder(context, i);
            return i < firstRowsReveal
                ? Reveal(
                    delay: Duration(milliseconds: 40 * i),
                    rise: 8,
                    child: row,
                  )
                : row;
          },
        ),
      ),
    );
  }
}

/// A row of a [ListPanel]: even padding, and a light tint under the mouse so it is clear what a click would hit.
class PanelRow extends StatelessWidget {
  const PanelRow({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    hoverColor: context.appColors.selected.withValues(alpha: 0.5),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      child: child,
    ),
  );
}
