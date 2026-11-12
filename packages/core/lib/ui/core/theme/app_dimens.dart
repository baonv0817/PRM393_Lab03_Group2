/// Spacing, corner radii, minimum sizes (Lab 2: 4 dp grid, 16 dp margins).
/// Spacing names match the Figma tokens: `spacing-xxs` 4 · `xs` 8 · `sm` 12 · `md` 16 · `lg` 24 · `xl` 32.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Standard horizontal screen margin.
  static const double screenPadding = 16;
}

abstract final class AppRadius {
  static const double chip = 8;
  static const double input = 12;
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 999;
}

abstract final class AppElevation {
  static const double flat = 0;
  static const double card = 1;
  static const double sheet = 4;
}

/// Lab 2 accessibility thresholds.
abstract final class AppA11y {
  /// Minimum touch target (dp).
  static const double minTouchTarget = 48;

  /// Minimum body text size (sp).
  static const double minBodyText = 14;
}
