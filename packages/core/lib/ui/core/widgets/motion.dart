import 'package:flutter/material.dart';

/// Brings [child] in with a short fade and a small rise, once, when it first appears. The motion shows what is new
/// on the page (a page that was just opened, a figure that arrived) and does nothing else; it is switched off when
/// the person asked the system for less motion.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.rise = 12,
  });

  final Widget child;

  /// How long to wait before the motion starts, to bring a row of things in one after another.
  final Duration delay;
  final Duration duration;

  /// How far below its place the child starts, in logical pixels.
  final double rise;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final total = delay + duration;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * rise), child: child),
      ),
    );
  }
}

/// A number that counts up to [value] when it appears and counts from the old value to the new one when it changes,
/// so a change in the figures is seen and not only read. With reduced motion it just shows the value.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  final num value;

  /// Turns the number on its way (a whole number) into text, for example `formatVnd`.
  final String Function(int value) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return Text(format(value.round()), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v.round()), style: style),
    );
  }
}
