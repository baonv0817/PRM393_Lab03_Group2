import 'dart:io' show Platform;

import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Whether this device can show the live camera of K05: phones only. Tests and desktop runs keep the
/// static frame, so they never open a camera.
bool get qrCameraSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// K05: the live camera inside the scan frame. Every QR code it reads goes to [onCode] once; the same code
/// is not sent again until another one has been read, so a code held in front of the camera is not looked
/// up over and over. When the camera cannot open (permission refused, no camera), it says so and the typed
/// code below still works.
class QrCameraView extends StatefulWidget {
  const QrCameraView({super.key, required this.onCode, required this.borderColor});

  final ValueChanged<String> onCode;
  final Color borderColor;

  @override
  State<QrCameraView> createState() => _QrCameraViewState();
}

class _QrCameraViewState extends State<QrCameraView> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  String? _last;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull?.trim();
    if (value == null || value.isEmpty || value == _last) return;
    _last = value;
    widget.onCode(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Camera quét mã QR',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: widget.borderColor, width: 3),
          ),
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => ColoredBox(
              color: colors.surfaceVariant,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'Chưa cho phép dùng camera. Bật quyền camera trong Cài đặt, hoặc nhập mã bên dưới.'
                        : 'Không mở được camera. Nhập mã bên dưới.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: colors.muted),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
