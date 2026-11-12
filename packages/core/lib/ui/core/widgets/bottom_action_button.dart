import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:breakbite_core/ui/core/widgets/test_id.dart';
import 'package:flutter/material.dart';

class BottomActionButton extends StatelessWidget {
  const BottomActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.testId,
    this.icon,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    this.secondaryTestId,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? testId;
  final IconData? icon;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;
  final String? secondaryTestId;

  static Widget _id(String? id, Widget child) => id == null ? child : TestId(id, child: child);

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryLabel;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.xs,
          AppSpacing.screenPadding,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (secondary != null) ...[
              _id(
                secondaryTestId,
                AppButton(
                  label: secondary,
                  icon: secondaryIcon,
                  variant: AppButtonVariant.secondary,
                  large: true,
                  onPressed: loading ? null : onSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _id(testId, AppButton(label: label, icon: icon, loading: loading, onPressed: onPressed)),
          ],
        ),
      ),
    );
  }
}
