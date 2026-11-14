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
    final colors = context.appColors;
    final isThumbnail = height == null;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: height ?? size,
        padding: isThumbnail ? const EdgeInsets.all(3) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: colors.selected,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: isThumbnail ? Border.all(color: colors.selectedBorder, width: 1.5) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isThumbnail ? AppRadius.input - 3 : AppRadius.input),
          child: _image(context),
        ),
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
