/// Khoảng cách, bo góc, kích thước tối thiểu (Lab 2: lưới 4 dp, lề 16 dp).
/// Tên khoảng cách trùng token Figma: `spacing-xxs` 4 · `xs` 8 · `sm` 12 · `md` 16 · `lg` 24 · `xl` 32.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Lề ngang chuẩn của màn hình.
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

/// Ngưỡng accessibility của Lab 2.
abstract final class AppA11y {
  /// Vùng chạm tối thiểu (dp).
  static const double minTouchTarget = 48;

  /// Cỡ chữ nội dung tối thiểu (sp).
  static const double minBodyText = 14;
}
