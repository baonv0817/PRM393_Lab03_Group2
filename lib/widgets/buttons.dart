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
    if (filled) {
      // Hình tròn cam 40 dp trong vùng chạm 48 dp (Figma: nút + trên thẻ món).
      final enabled = onPressed != null;
      return Tooltip(
        message: semanticLabel,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: semanticLabel,
          excludeSemantics: true,
          child: SizedBox.square(
            dimension: AppA11y.minTouchTarget,
            child: InkResponse(
              onTap: onPressed,
              radius: AppA11y.minTouchTarget / 2,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: enabled ? scheme.primary : context.appColors.border, shape: BoxShape.circle),
                  child: Icon(icon, color: scheme.onPrimary),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return IconButton(
      onPressed: onPressed,
      tooltip: semanticLabel,
      icon: Icon(icon),
      constraints: const BoxConstraints.tightFor(
        width: AppA11y.minTouchTarget,
        height: AppA11y.minTouchTarget,
      ),
      style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
    );
  }
}

/// Nút icon kèm huy hiệu: số đếm cam (giỏ hàng) hoặc chấm đỏ (thông báo chưa đọc).
/// `semanticLabel` nên đã chứa số đếm, ví dụ "Giỏ hàng, 2 món".
class AppBadgeIconButton extends StatelessWidget {
  const AppBadgeIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.count = 0,
    this.showDot = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final int count;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(icon: icon, semanticLabel: semanticLabel, onPressed: onPressed),
        if (count > 0)
          Positioned(
            right: 2,
            top: 2,
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text('$count', style: text.labelLarge?.copyWith(fontSize: 12, color: scheme.onPrimary, height: 1.2)),
              ),
            ),
          )
        else if (showDot)
          Positioned(
            right: 10,
            top: 10,
            child: ExcludeSemantics(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle),
              ),
            ),
          ),
      ],
    );
  }
}
