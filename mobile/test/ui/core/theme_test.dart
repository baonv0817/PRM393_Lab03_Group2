import 'dart:math' as math;

import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  group('Lab 2 accessibility: text contrast ≥ 4.5:1', () {
    const pairs = {
      'button text (brown) on orange': (AppPalette.onPrimary, AppPalette.primary),
      'primary text on background': (AppPalette.onPrimary, AppPalette.background),
      'primary text on card': (AppPalette.onPrimary, AppPalette.surface),
      'secondary text on card': (AppPalette.muted, AppPalette.surface),
      'accent text on background': (AppPalette.primaryText, AppPalette.background),
      'success text on card': (AppPalette.success, AppPalette.surface),
      'error text on card': (AppPalette.error, AppPalette.surface),
      'error text on its light background': (AppPalette.error, AppPalette.errorContainer),
      'primary text on selected item': (AppPalette.onPrimary, AppPalette.selected),
    };
    pairs.forEach((name, p) {
      test(name, () => expect(contrast(p.$1, p.$2), greaterThanOrEqualTo(4.5)));
    });
  });

  test('white text on orange fails (why button text is brown)', () {
    expect(contrast(AppPalette.surface, AppPalette.primary), lessThan(3));
  });

  test('theme uses tokens and no font size is below 14 sp', () {
    final text = AppTheme.light().textTheme;
    for (final style in [
      text.headlineMedium,
      text.headlineSmall,
      text.titleMedium,
      text.bodyLarge,
      text.bodyMedium,
      text.labelLarge,
    ]) {
      expect(style!.fontSize, greaterThanOrEqualTo(14));
    }
    expect(AppTheme.light().colorScheme.primary, AppPalette.primary);
  });
}
