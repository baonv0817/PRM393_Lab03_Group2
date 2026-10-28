import 'package:flutter/material.dart';

/// Token màu Lab 2 (Figma Variables "BreakBite Design Tokens").
/// Màn hình không dùng mã màu trực tiếp: lấy từ `Theme.of(context).colorScheme`
/// hoặc từ [AppColors] (`context.appColors`).
abstract final class AppPalette {
  static const primary = Color(0xFFF69D39);
  static const onPrimary = Color(0xFF622B14);
  static const primaryText = Color(0xFFB45309);
  static const background = Color(0xFFFAF8F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF3F0EA);
  static const selected = Color(0xFFFFF1DE);
  static const border = Color(0xFFE4DFD8);
  static const borderInput = Color(0xFF8A7A70);
  static const muted = Color(0xFF6B5F55);
  static const success = Color(0xFF15803D);
  static const error = Color(0xFFB91C1C);
}

/// Token không có chỗ trong [ColorScheme] của Material.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primaryText,
    required this.selected,
    required this.border,
    required this.borderInput,
    required this.muted,
    required this.success,
    required this.surfaceVariant,
  });

  final Color primaryText;
  final Color selected;
  final Color border;
  final Color borderInput;
  final Color muted;
  final Color success;
  final Color surfaceVariant;

  static const light = AppColors(
    primaryText: AppPalette.primaryText,
    selected: AppPalette.selected,
    border: AppPalette.border,
    borderInput: AppPalette.borderInput,
    muted: AppPalette.muted,
    success: AppPalette.success,
    surfaceVariant: AppPalette.surfaceVariant,
  );

  @override
  AppColors copyWith({
    Color? primaryText,
    Color? selected,
    Color? border,
    Color? borderInput,
    Color? muted,
    Color? success,
    Color? surfaceVariant,
  }) =>
      AppColors(
        primaryText: primaryText ?? this.primaryText,
        selected: selected ?? this.selected,
        border: border ?? this.border,
        borderInput: borderInput ?? this.borderInput,
        muted: muted ?? this.muted,
        success: success ?? this.success,
        surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderInput: Color.lerp(borderInput, other.borderInput, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      success: Color.lerp(success, other.success, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
