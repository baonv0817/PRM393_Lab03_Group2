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

/// K05 and K05-ERR: the counter's "scan" tab. On a phone the frame is the camera and a QR code opens the order
/// in K06; where there is no camera (the fake-data app, tests, a refused permission) the frame only shows where
/// the code would go, and staff type the 6-digit pickup code or the order number instead.
class SellerScanScreen extends StatefulWidget {
  const SellerScanScreen({super.key});

  @override
  State<SellerScanScreen> createState() => _SellerScanScreenState();
}

class _SellerScanScreenState extends State<SellerScanScreen> {
  static const _repeatAfter = Duration(seconds: 3);

  final _input = TextEditingController();
  bool _orderOpen = false;
  String? _lastCode;
  DateTime? _lastCodeAt;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _find(SellerScanViewModel vm) async {
    final result = await vm.find(_input.text);
    if (!mounted) return;
    if (result case Ok(:final value)) {
      _input.clear();
      _orderOpen = true;
      await context.push(AppRoutes.sellerOrderDeliverOf(value.id));
      _orderOpen = false;
    }
  }

  /// A code read by the camera. The camera keeps seeing the same code, so the same one is not tried again for a
  /// few seconds, and nothing is tried while K06 is open on top of this tab or a search is running.
  void _onCode(SellerScanViewModel vm, String code) {
    if (_orderOpen || vm.searching) return;
    final now = DateTime.now();
    final last = _lastCodeAt;
    if (code == _lastCode && last != null && now.difference(last) < _repeatAfter) return;
    _lastCode = code;
    _lastCodeAt = now;
    _input.text = code;
    unawaited(_find(vm));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellerScanViewModel>();
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final error = vm.error;
    final camera = context.read<QrCameraBuilder?>();
    final frameColor = error == null ? colors.primaryText : scheme.error;
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: frameColor, width: 3),
                      ),
                      child: camera == null
                          ? Icon(Icons.qr_code_2, size: 96, color: frameColor, semanticLabel: 'Mã QR')
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.card - 3),
                              child: camera(context, (code) => _onCode(vm, code)),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (error == null)
                Text(
                  camera == null
                      ? 'Hỏi khách mã 6 số dưới mã QR, hoặc số đơn như #A-204.'
                      : 'Hướng camera vào mã QR của khách, hoặc nhập mã 6 số, số đơn như #A-204 bên dưới.',
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
