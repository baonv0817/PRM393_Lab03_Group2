import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Draws a camera that reads QR codes and calls `onCode` with the text of each code it sees. The scan screen
/// takes one from `BreakBiteApp`, so tests and the fake-data app (no camera) leave it out and the screen
/// keeps its typed entry.
typedef QrCameraBuilder = Widget Function(BuildContext context, ValueChanged<String> onCode);

/// The real camera, for a phone: the back camera, QR codes only.
Widget mobileScannerCamera(BuildContext context, ValueChanged<String> onCode) => _QrCameraView(onCode: onCode);

class _QrCameraView extends StatefulWidget {
  const _QrCameraView({required this.onCode});

  final ValueChanged<String> onCode;

  @override
  State<_QrCameraView> createState() => _QrCameraViewState();
}

class _QrCameraViewState extends State<_QrCameraView> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
        if (code != null && code.isNotEmpty) widget.onCode(code);
      },
      errorBuilder: (context, error) =>
          _CameraProblem(denied: error.errorCode == MobileScannerErrorCode.permissionDenied),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.denied});

  final bool denied;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography_outlined, size: 48, color: scheme.error),
            const SizedBox(height: 8),
            Text(
              denied
                  ? 'Chưa cho phép dùng camera. Bật quyền Camera trong cài đặt, hoặc nhập mã bên dưới.'
                  : 'Không mở được camera. Nhập mã bên dưới.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
