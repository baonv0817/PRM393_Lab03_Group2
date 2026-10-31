import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:breakbite/ui/core/theme/app_colors.dart';

/// Biến thể logo: `brand` (nền cam, dùng ở Onboarding và icon app) hoặc `soft` (nền xám nhạt, dùng
/// làm ảnh giữ chỗ trên thẻ món khi chưa có ảnh thật).
enum LogoVariant { brand, soft }

/// Logo BreakBite: chiếc bánh bị cắn một miếng (Bite) với chữ B ở giữa. Nguồn: `assets/brand/`.
class BreakBiteLogo extends StatelessWidget {
  const BreakBiteLogo({super.key, this.size = 96, this.variant = LogoVariant.brand});

  final double size;
  final LogoVariant variant;

  static const _assets = {
    LogoVariant.brand: 'assets/brand/breakbite_logo.svg',
    LogoVariant.soft: 'assets/brand/breakbite_logo_soft.svg',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Logo BreakBite',
      child: ExcludeSemantics(
        child: SvgPicture.asset(_assets[variant]!, width: size, height: size),
      ),
    );
  }
}

/// Tên thương hiệu "BreakBite": "Break" màu nâu chính, "Bite" màu cam nhấn.
class BreakBiteWordmark extends StatelessWidget {
  const BreakBiteWordmark({super.key, this.fontSize = 36});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: fontSize, fontWeight: FontWeight.w800, height: 1.2);
    return Semantics(
      header: true,
      label: 'BreakBite',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              const TextSpan(text: 'Break'),
              TextSpan(text: 'Bite', style: TextStyle(color: context.appColors.primaryText)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
