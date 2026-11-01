import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<void> flyToCart({
  required BuildContext context,
  required GlobalKey from,
  required GlobalKey to,
  required Widget child,
  double size = 80,
  Duration duration = const Duration(milliseconds: 600),
}) async {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
  final overlay = Overlay.maybeOf(context);
  final fromBox = from.currentContext?.findRenderObject();
  final toBox = to.currentContext?.findRenderObject();
  final overlayBox = overlay?.context.findRenderObject();
  if (overlay == null || fromBox is! RenderBox || toBox is! RenderBox || overlayBox is! RenderBox) return;
  if (!fromBox.attached || !toBox.attached) return;

  final start = overlayBox.globalToLocal(fromBox.localToGlobal(fromBox.size.center(Offset.zero)));
  final end = overlayBox.globalToLocal(toBox.localToGlobal(toBox.size.center(Offset.zero)));
  final control = Offset(start.dx + (end.dx - start.dx) * 0.25, math.min(start.dy, end.dy) - 60);
  final scheme = Theme.of(context).colorScheme;
  final controller = AnimationController(vsync: overlay, duration: duration);
  final progress = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        final u = 1 - t;
        final point = start * (u * u) + control * (2 * u * t) + end * (t * t);
        final scale = 0.8 - 0.55 * t;
        return Positioned(
          left: point.dx - size / 2,
          top: point.dy - size / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: t < 0.85 ? 1 : (1 - t) / 0.15,
              child: Transform.scale(
                scale: scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 3),
                    boxShadow: [
                      BoxShadow(color: scheme.shadow.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: SizedBox.square(
                    dimension: size,
                    child: ClipOval(child: child),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
  overlay.insert(entry);
  try {
    await controller.forward();
  } finally {
    entry.remove();
    controller.dispose();
  }
}

class BumpOnIncrease extends StatefulWidget {
  const BumpOnIncrease({super.key, required this.value, required this.child});

  final int value;
  final Widget child;

  @override
  State<BumpOnIncrease> createState() => _BumpOnIncreaseState();
}

class _BumpOnIncreaseState extends State<BumpOnIncrease> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.25).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.25, end: 1).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 60,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(BumpOnIncrease oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.value > oldWidget.value && !reduceMotion) unawaited(_controller.forward(from: 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}
