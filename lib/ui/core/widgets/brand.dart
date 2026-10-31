import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo variant: `brand` (orange background, used on Onboarding and the app icon) or `soft` (light gray
/// background, used as the placeholder image on menu item cards until a real photo exists).
enum LogoVariant { brand, soft }

/// BreakBite logo: a bun with one bite taken out (Bite) and a B in the middle. Source: `assets/brand/`.
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

/// "BreakBite" brand name: "Break" in the primary brown, "Bite" in the orange accent.
class BreakBiteWordmark extends StatelessWidget {
  const BreakBiteWordmark({super.key, this.fontSize = 36});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium
        ?.copyWith(fontSize: fontSize, fontWeight: FontWeight.w800, height: 1.2);
    return Semantics(
      header: true,
      label: 'BreakBite',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              const TextSpan(text: 'Break'),
              TextSpan(
                text: 'Bite',
                style: TextStyle(color: context.appColors.primaryText),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
