import 'dart:async';

import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_scan_view_model.dart';
import 'package:breakbite/ui/seller_orders/widgets/qr_camera_view.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// K05 and K05-ERR: the counter's "scan" tab. On a phone the frame is the live camera and reading the
/// customer's QR code opens the order in K06; staff can also type the 6-digit pickup code or the order
/// number. Where there is no camera (tests, desktop) the frame only shows where the code goes.
class SellerScanScreen extends StatefulWidget {
  const SellerScanScreen({super.key, this.camera});

  /// Show the live camera; `null` means "on phones" ([qrCameraSupported]).
  final bool? camera;

  @override
  State<SellerScanScreen> createState() => _SellerScanScreenState();
}

class _SellerScanScreenState extends State<SellerScanScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _find(SellerScanViewModel vm) => _open(vm, _input.text);

  /// A QR code read by the camera; ignored while a search is running.
  Future<void> _scanned(SellerScanViewModel vm, String code) async {
    if (vm.searching) return;
    await _open(vm, code);
  }

  Future<void> _open(SellerScanViewModel vm, String input) async {
    final result = await vm.find(input);
    if (!mounted) return;
    if (result case Ok(:final value)) {
      _input.clear();
      unawaited(context.push(AppRoutes.sellerOrderDeliverOf(value.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellerScanViewModel>();
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final error = vm.error;
    final frameColor = error == null ? colors.primaryText : scheme.error;
    final camera = widget.camera ?? qrCameraSupported;
    return Scaffold(
      appBar: const AppTopBar(title: 'Quét mã nhận món'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              TestId(
                'k05.frame',
                child: Semantics(
                  label: 'Khung quét mã QR',
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: camera
                        ? QrCameraView(borderColor: frameColor, onCode: (code) => _scanned(vm, code))
                        : Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              border: Border.all(color: frameColor, width: 3),
                            ),
                            child: Icon(Icons.qr_code_2, size: 96, color: frameColor, semanticLabel: 'Mã QR'),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (error == null)
                Text(
                  camera
                      ? 'Đưa mã QR của khách vào khung, hoặc nhập mã 6 số / số đơn như #A-204.'
                      : 'Hỏi khách mã 6 số dưới mã QR, hoặc số đơn như #A-204.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: colors.muted),
                )
              else
                TestId(
                  'k05.error',
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(color: scheme.error),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: scheme.error),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(error, style: text.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text('nhập mã nhận món', style: text.labelLarge?.copyWith(color: colors.primaryText)),
              ),
              const SizedBox(height: AppSpacing.xs),
              TestId(
                'k05.input',
                child: AppTextField(
                  label: 'Mã nhận món hoặc số đơn',
                  hint: '#A-204 hoặc 100 204',
                  controller: _input,
                  onChanged: (_) => vm.clearError(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TestId(
                'k05.find',
                child: AppButton(
                  label: 'Tìm đơn',
                  variant: AppButtonVariant.secondary,
                  large: true,
                  loading: vm.searching,
                  onPressed: () => _find(vm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
