import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const String fontFamily = 'Nunito';

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.primary,
    onPrimary: AppPalette.onPrimary,
    secondary: AppPalette.primaryText,
    onSecondary: AppPalette.surface,
    error: AppPalette.error,
    onError: AppPalette.surface,
    surface: AppPalette.surface,
    onSurface: AppPalette.onPrimary,
    surfaceContainerHighest: AppPalette.surfaceVariant,
    onSurfaceVariant: AppPalette.muted,
    outline: AppPalette.borderInput,
    outlineVariant: AppPalette.border,
    primaryContainer: AppPalette.selected,
    onPrimaryContainer: AppPalette.onPrimary,
  );

  static const TextTheme textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 24, height: 1.33, fontWeight: FontWeight.w700),
    headlineSmall: TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w700),
  );

  static ThemeData light() {
    final text = textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: AppPalette.onPrimary,
      displayColor: AppPalette.onPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.background,
      fontFamily: fontFamily,
      textTheme: text,
      extensions: const [AppColors.light],
      dividerColor: AppPalette.border,
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.background,
        foregroundColor: AppPalette.onPrimary,
        elevation: AppElevation.flat,
        scrolledUnderElevation: AppElevation.flat,
        titleTextStyle: text.headlineSmall,
        shape: const Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      cardTheme: CardThemeData(
        color: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.flat,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppPalette.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppPalette.borderInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppPalette.borderInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppPalette.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppPalette.error),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.flat,
        indicatorColor: AppPalette.selected,
        indicatorShape: const StadiumBorder(),
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? AppPalette.primaryText : AppPalette.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelLarge?.copyWith(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? AppPalette.primaryText : AppPalette.muted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.onPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppPalette.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
      ),
    );
  }
}
