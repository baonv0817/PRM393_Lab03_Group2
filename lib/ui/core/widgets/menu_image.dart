import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/brand.dart';
import 'package:flutter/material.dart';

/// Dish image. `imageUrl` is an image path bundled in the app (`assets/images/menu/…`) or an
/// `https://` link (an image the seller uploaded to Cloud Storage). A missing or broken image shows the soft logo.
class MenuItemImage extends StatelessWidget {
  const MenuItemImage({super.key, required this.imageUrl, this.size = 80});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    // The dish name is already in the card's accessibility label, so the image needs no extra label.
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: SizedBox.square(dimension: size, child: _image(context)),
      ),
    );
  }

  Widget _fallback() => BreakBiteLogo(size: size, variant: LogoVariant.soft);

  Widget _image(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return _fallback();
    final decodeWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();
    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: BoxFit.cover, cacheWidth: decodeWidth, errorBuilder: (_, _, _) => _fallback());
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
