import 'package:barcode/barcode.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PickupQrCode extends StatelessWidget {
  const PickupQrCode({super.key, required this.data, required this.semanticLabel, this.size = 180});

  final String data;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final svg = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium)
        .toSvg(data, width: size, height: size, drawText: false, color: scheme.onSurface.toARGB32() & 0xFFFFFF);
    return Semantics(
      image: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        color: scheme.surface,
        child: SvgPicture.string(svg, width: size, height: size),
      ),
    );
  }
}
