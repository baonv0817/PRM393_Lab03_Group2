import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// The theme of the admin website: the theme of the app (same colours, same type, same corner radii) with what a
/// site on a wide screen needs on top: a side menu that matches, buttons and rows that answer a mouse, and pages
/// that come in with a short fade instead of snapping.
abstract final class AdminTheme {
  static ThemeData light() {
    final base = AppTheme.light();
    final text = base.textTheme;
    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeRiseTransitions(),
          TargetPlatform.iOS: _FadeRiseTransitions(),
          TargetPlatform.windows: _FadeRiseTransitions(),
          TargetPlatform.macOS: _FadeRiseTransitions(),
          TargetPlatform.linux: _FadeRiseTransitions(),
          TargetPlatform.fuchsia: _FadeRiseTransitions(),
        },
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppPalette.surface,
        indicatorColor: AppPalette.selected,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
        minExtendedWidth: 216,
        selectedIconTheme: const IconThemeData(color: AppPalette.primaryText, size: 22),
        unselectedIconTheme: const IconThemeData(color: AppPalette.muted, size: 22),
        selectedLabelTextStyle: text.labelLarge?.copyWith(color: AppPalette.primaryText, fontWeight: FontWeight.w800),
        unselectedLabelTextStyle: text.labelLarge?.copyWith(color: AppPalette.muted, fontWeight: FontWeight.w600),
      ),
      dividerTheme: const DividerThemeData(color: AppPalette.border, space: 1, thickness: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppPalette.onPrimary, borderRadius: BorderRadius.circular(AppRadius.chip)),
        textStyle: text.bodySmall?.copyWith(color: AppPalette.surface),
        waitDuration: const Duration(milliseconds: 400),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(AppRadius.pill),
        thumbColor: WidgetStatePropertyAll(AppPalette.borderInput.withValues(alpha: 0.45)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppPalette.border),
        ),
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppPalette.onPrimary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          side: const BorderSide(color: AppPalette.border),
        ),
        color: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        textStyle: text.bodyMedium?.copyWith(color: AppPalette.onPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: const BorderSide(color: AppPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: const BorderSide(color: AppPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: const BorderSide(color: AppPalette.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          borderSide: const BorderSide(color: AppPalette.error, width: 1.5),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: AppPalette.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          ),
          textStyle: WidgetStatePropertyAll(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: AppPalette.border)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          ),
          textStyle: WidgetStatePropertyAll(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip))),
          overlayColor: WidgetStatePropertyAll(AppPalette.selected.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}

/// A page comes in with a fade and a short rise (8 px), and the page it replaces stays where it is. It tells the
/// person that the content changed without moving the frame of the site, and is quick enough not to be waited for.
class _FadeRiseTransitions extends PageTransitionsBuilder {
  const _FadeRiseTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.012), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
