import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:breakbite_core/ui/core/widgets/test_id.dart';
import 'package:flutter/material.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.name,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.testId,
    this.removesAtOne = true,
  });

  final String name;
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final String? testId;
  final bool removesAtOne;

  Widget _id(String suffix, Widget child) => testId == null ? child : TestId('$testId.$suffix', child: child);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.selected,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.selectedBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _id(
            'dec',
            AppIconButton(
              icon: quantity == 1 && removesAtOne ? Icons.delete_outline : Icons.remove,
              semanticLabel: quantity == 1 && removesAtOne ? 'Bỏ $name khỏi giỏ' : 'Bớt 1 $name',
              onPressed: onDecrement,
            ),
          ),
          _id(
            'qty',
            Semantics(
              liveRegion: true,
              label: 'Số lượng $quantity',
              excludeSemantics: true,
              child: SizedBox(
                width: 24,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: Text(
                    '$quantity',
                    key: ValueKey(quantity),
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
          _id(
            'inc',
            AppIconButton(icon: Icons.add, semanticLabel: 'Thêm 1 $name', onPressed: onIncrement, filled: true),
          ),
        ],
      ),
    );
  }
}
