import 'dart:math' as math;

import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/ui/core/theme/order_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.2 contrast ratio of two colours.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  }

  final x = lum(a), y = lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test('every order status has its own stage', () {
    for (final status in OrderStatus.values) {
      expect(OrderStage.all, contains(OrderStage.of(status)));
    }
    expect(OrderStage.all.map((s) => s.color).toSet(), hasLength(5), reason: 'five stages, five colours');
    expect(OrderStage.all.map((s) => s.icon).toSet(), hasLength(5), reason: 'the icon says it without the colour');
  });

  test('the tracking steps are the four stages in the order they happen', () {
    expect(OrderStage.steps, [OrderStage.pending, OrderStage.preparing, OrderStage.ready, OrderStage.delivered]);
  });

  test('the stage colour is readable on its tint and on white (4.5:1)', () {
    for (final stage in OrderStage.all) {
      expect(_contrast(stage.color, stage.tint), greaterThanOrEqualTo(4.5), reason: '${stage.icon} on its tint');
      expect(_contrast(stage.color, Colors.white), greaterThanOrEqualTo(4.5), reason: '${stage.icon} on white');
    }
  });
}
