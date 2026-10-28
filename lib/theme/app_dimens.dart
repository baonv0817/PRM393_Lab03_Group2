/// Khoảng cách, bo góc, kích thước tối thiểu (Lab 2: lưới 4 dp, lề 16 dp).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

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
