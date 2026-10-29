import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'brand.dart';

/// Ảnh món. `imageUrl` là đường dẫn ảnh đóng gói trong app (`assets/images/menu/…`) hoặc link
/// `https://` (ảnh seller tải lên Cloud Storage). Thiếu ảnh hoặc ảnh lỗi thì hiện logo bản nhạt.
class MenuItemImage extends StatelessWidget {
  const MenuItemImage({super.key, required this.imageUrl, this.size = 80});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Tên món đã nằm trong nhãn trợ năng của thẻ, nên ảnh không cần đọc thêm.
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
      loadingBuilder: (_, child, progress) => progress == null ? child : ColoredBox(color: context.appColors.surfaceVariant),
      errorBuilder: (_, _, _) => _fallback(),
    );
  }
}
