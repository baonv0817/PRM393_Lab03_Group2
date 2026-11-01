import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/buttons.dart';
import 'package:breakbite/ui/core/widgets/test_id.dart';
import 'package:flutter/material.dart';

class BottomActionButton extends StatelessWidget {
  const BottomActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.testId,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? testId;

  @override
  Widget build(BuildContext context) {
    final button = AppButton(label: label, loading: loading, onPressed: onPressed);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.xs,
          AppSpacing.screenPadding,
          AppSpacing.md,
        ),
        child: SizedBox(
          width: double.infinity,
          child: testId == null ? button : TestId(testId!, child: button),
        ),
      ),
    );
  }
}
