import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/brand.dart';
import 'package:flutter/material.dart';

class MenuItemImage extends StatelessWidget {
  const MenuItemImage({super.key, required this.imageUrl, this.size = 80, this.height});

  final String? imageUrl;
  final double size;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: SizedBox(width: size, height: height ?? size, child: _image(context)),
      ),
    );
  }

  Widget _fallback() => BreakBiteLogo(size: size, variant: LogoVariant.soft);

  Widget _image(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return _fallback();
    final decodeWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        package: corePackage,
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: decodeWidth,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : ColoredBox(color: context.appColors.surfaceVariant),
      errorBuilder: (_, _, _) => _fallback(),
    );
  }
}
