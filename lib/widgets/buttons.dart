import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

enum AppButtonVariant { primary, secondary, text }

/// Button/Primary, Button/Secondary, Button/Text của Lab 2.
/// Trạng thái: mặc định, nhấn, vô hiệu (`onPressed: null`), đang tải (`loading`).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16);
    final height = variant == AppButtonVariant.primary ? 56.0 : AppA11y.minTouchTarget;
    final enabled = onPressed != null && !loading;
    final onTap = enabled ? onPressed : null;

    final Widget content = loading
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: textStyle),
          ])
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: AppSpacing.sm)],
            Text(label, style: textStyle),
          ]);

    final size = Size(AppA11y.minTouchTarget, height);
    final shape = const StadiumBorder();

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            minimumSize: size,
            shape: shape,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            disabledBackgroundColor: colors.border,
            disabledForegroundColor: colors.muted,
          ),
          child: content,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            shape: shape,
            foregroundColor: scheme.onSurface,
            side: BorderSide(color: enabled ? colors.borderInput : colors.border, width: 2),
          ),
          child: content,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: size,
            foregroundColor: colors.primaryText,
          ),
          child: content,
        ),
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// IconButton 48 × 48 của Lab 2. `semanticLabel` bắt buộc để ARTEMIS và trình đọc màn hình hiểu nút.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Nút tròn cam (nút + trên thẻ món).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: semanticLabel,
      icon: Icon(icon),
      constraints: const BoxConstraints.tightFor(
        width: AppA11y.minTouchTarget,
        height: AppA11y.minTouchTarget,
      ),
      style: filled
          ? IconButton.styleFrom(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary)
          : IconButton.styleFrom(foregroundColor: scheme.onSurface),
    );
  }
}
