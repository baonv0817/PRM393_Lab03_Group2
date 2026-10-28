import 'dart:math' as math;

import 'package:breakbite/theme/app_colors.dart';
import 'package:breakbite/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tỉ lệ tương phản WCAG 2.x.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Lab 2 accessibility: tương phản chữ ≥ 4,5:1', () {
    const pairs = {
      'chữ nút (nâu) trên cam': (AppPalette.onPrimary, AppPalette.primary),
      'chữ chính trên nền': (AppPalette.onPrimary, AppPalette.background),
      'chữ chính trên thẻ': (AppPalette.onPrimary, AppPalette.surface),
      'chữ phụ trên thẻ': (AppPalette.muted, AppPalette.surface),
      'chữ nhấn trên nền': (AppPalette.primaryText, AppPalette.background),
      'chữ thành công trên thẻ': (AppPalette.success, AppPalette.surface),
      'chữ lỗi trên thẻ': (AppPalette.error, AppPalette.surface),
      'chữ chính trên mục đang chọn': (AppPalette.onPrimary, AppPalette.selected),
    };
    pairs.forEach((name, p) {
      test(name, () => expect(contrast(p.$1, p.$2), greaterThanOrEqualTo(4.5)));
    });
  });

  test('chữ trắng trên cam không đạt (lý do đổi sang chữ nâu)', () {
    expect(contrast(AppPalette.surface, AppPalette.primary), lessThan(3));
  });

  test('theme dùng token, không cỡ chữ dưới 14 sp', () {
    final text = AppTheme.light().textTheme;
    for (final style in [text.headlineMedium, text.headlineSmall, text.titleMedium, text.bodyLarge, text.bodyMedium, text.labelLarge]) {
      expect(style!.fontSize, greaterThanOrEqualTo(14));
    }
    expect(AppTheme.light().colorScheme.primary, AppPalette.primary);
  });
}
