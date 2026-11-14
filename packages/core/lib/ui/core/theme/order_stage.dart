import 'package:breakbite_core/domain/models/order.dart';
import 'package:flutter/material.dart';

/// How an order looks at each stage, so a customer (or a counter) tells "waiting", "being made", "ready", "picked up"
/// and "cancelled" apart at a glance. The colour never carries the meaning alone: every stage has its own icon and
/// word too. Each pair of [color] on [tint] has a contrast of at least 4.5:1 (tested), so text in [color] on [tint]
/// or on white is readable.
@immutable
class OrderStage {
  const OrderStage({required this.color, required this.tint, required this.icon});

  /// Text, icon and borders of the stage.
  final Color color;

  /// A soft background of the same hue, behind a banner or a badge.
  final Color tint;
  final IconData icon;

  static const pending = OrderStage(color: Color(0xFFB45309), tint: Color(0xFFFEF3C7), icon: Icons.hourglass_top);
  static const preparing = OrderStage(color: Color(0xFF1D4ED8), tint: Color(0xFFDBEAFE), icon: Icons.soup_kitchen);
  static const ready = OrderStage(color: Color(0xFF15803D), tint: Color(0xFFDCFCE7), icon: Icons.notifications_active);
  static const delivered = OrderStage(color: Color(0xFF0F766E), tint: Color(0xFFCCFBF1), icon: Icons.done_all);
  static const cancelled = OrderStage(color: Color(0xFFB91C1C), tint: Color(0xFFFEE2E2), icon: Icons.cancel);

  /// The four steps of the order in the order they happen: the stages the tracking bar walks through.
  static const steps = [pending, preparing, ready, delivered];

  static const all = [pending, preparing, ready, delivered, cancelled];

  static OrderStage of(OrderStatus status) => switch (status) {
    OrderStatus.pending => pending,
    OrderStatus.preparing => preparing,
    OrderStatus.ready => ready,
    OrderStatus.delivered => delivered,
    OrderStatus.cancelled => cancelled,
  };
}
