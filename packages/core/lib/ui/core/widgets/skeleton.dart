import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:flutter/material.dart';

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = AppRadius.input, this.circle = false});

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: circle ? height : width,
    height: height,
    decoration: BoxDecoration(
      color: context.appColors.surfaceVariant,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
    ),
  );
}

class FoodCardSkeleton extends StatelessWidget {
  const FoodCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          SkeletonBox(width: 80, height: 80),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(widthFactor: 0.9, child: SkeletonBox(height: 16, radius: AppRadius.pill)),
                SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(widthFactor: 0.6, child: SkeletonBox(height: 12, radius: AppRadius.pill)),
                SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(widthFactor: 0.4, child: SkeletonBox(height: 12, radius: AppRadius.pill)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3, this.label = 'Đang tải…', this.leading = const []});

  final int count;
  final String label;
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    liveRegion: true,
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...leading,
        for (var i = 0; i < count; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.xs),
            child: FoodCardSkeleton(),
          ),
      ],
    ),
  );
}
