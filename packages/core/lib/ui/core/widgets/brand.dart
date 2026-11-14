import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The package that bundles the logo, the menu photos and the Nunito font (`packages/core/assets/`).
/// Pass it as `package:` to `Image.asset` and `SvgPicture.asset` so both clients load the same files.
const String corePackage = 'breakbite_core';

/// Logo variant: `brand` (orange background, used on Onboarding and the app icon) or `soft` (light gray
/// background, used as the placeholder image on menu item cards until a real photo exists).
enum LogoVariant { brand, soft }

/// PRMTacos logo: a tortilla medallion with one bite taken out and a folded taco shell with a 'T' monogram. Source: `assets/brand/`.
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
      label: 'Logo PRMTacos',
      child: ExcludeSemantics(
        child: SvgPicture.asset(_assets[variant]!, package: corePackage, width: size, height: size),
      ),
    );
  }
}

/// "PRMTacos" brand name: "PRM" in the primary brown, "Tacos" in the orange accent.
class BreakBiteWordmark extends StatelessWidget {
  const BreakBiteWordmark({super.key, this.fontSize = 36});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium
        ?.copyWith(fontSize: fontSize, fontWeight: FontWeight.w800, height: 1.2);
    return Semantics(
      header: true,
      label: 'PRMTacos',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              const TextSpan(text: 'PRM'),
              TextSpan(
                text: 'Tacos',
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
