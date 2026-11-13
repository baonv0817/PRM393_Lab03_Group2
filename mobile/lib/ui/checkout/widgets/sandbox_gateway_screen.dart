import 'dart:async';

import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/checkout/view_models/checkout_view_model.dart';
import 'package:breakbite_core/data/services/payment_gateway_service.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// S06-GATEWAY with a real gateway in its sandbox (D41): MoMo's or VNPAY's own payment page in a WebView. When the
/// gateway sends the customer back to [PaymentReturn.url] the app stops the page there and checks the result; leaving,
/// the countdown and a refused payment cancel the unpaid order and keep the cart, as on the simulated screen (D40).
class SandboxGatewayScreen extends StatefulWidget {
  const SandboxGatewayScreen({super.key});

  @override
  State<SandboxGatewayScreen> createState() => _SandboxGatewayScreenState();
}

class _SandboxGatewayScreenState extends State<SandboxGatewayScreen> {
  late final WebViewController _web;
  Timer? _ticker;
  bool _finished = false;
  int _progress = 0;

  /// The return address once the gateway sent the customer back; kept so a failed check can be tried again.
  Uri? _returned;
  String? _checkError;

  CheckoutViewModel get _vm => context.read<CheckoutViewModel>();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (PaymentReturn.matches(request.url)) {
              unawaited(_onReturn(Uri.parse(request.url)));
              return NavigationDecision.prevent;
            }
            final scheme = Uri.tryParse(request.url)?.scheme ?? '';
            if (scheme != 'http' && scheme != 'https') {
              // momo:// or intent:// would open the real MoMo app, which cannot pay a sandbox order.
              showAppMessage(context, 'Bản thử nghiệm không mở được ứng dụng khác. Chọn thanh toán bằng thẻ test.');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          // A server redirect does not always ask onNavigationRequest first, so check the address here too.
          onPageStarted: (url) {
            if (PaymentReturn.matches(url)) unawaited(_onReturn(Uri.parse(url)));
          },
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
        ),
      );
    final checkout = _vm.checkout;
    if (checkout != null) unawaited(_web.loadRequest(checkout.payUrl));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _finished) return;
    final deadline = _vm.gatewayDeadline;
    // Once the gateway answered, the countdown no longer matters: the payment may already have been taken.
    if (_returned == null && deadline != null && !_vm.now.isBefore(deadline)) {
      _leave(GatewayOutcome.expired);
    } else {
      setState(() {});
    }
  }

  void _leave(GatewayOutcome outcome) {
    if (_finished || _vm.complete.running || _vm.pay.running) return;
    _finished = true;
    _ticker?.cancel();
    unawaited(_vm.failGateway(outcome));
    if (context.canPop()) context.pop();
  }

  Future<void> _onReturn(Uri uri) async {
    if (_finished || _returned != null) return;
    setState(() => _returned = uri);
    await _check();
  }

  Future<void> _check() async {
    final uri = _returned;
    if (uri == null || _finished) return;
    final router = GoRouter.of(context);
    setState(() => _checkError = null);
    final result = await _vm.complete.execute(uri);
    if (result == null || !mounted) return;
    switch (result) {
      case Ok(value: final String orderId):
        _finished = true;
        _ticker?.cancel();
        router.go(AppRoutes.orderOf(orderId));
      case Ok():
        // Not paid: failGateway already ran, S06-ERR shows why and keeps the cart.
        _finished = true;
        _ticker?.cancel();
        if (router.canPop()) router.pop();
      case Err(:final error):
        setState(() => _checkError = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CheckoutViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final deadline = vm.gatewayDeadline;
    final left = deadline == null ? Duration.zero : deadline.difference(vm.now);
    final seconds = left.isNegative ? 0 : left.inSeconds;
    final countdown = '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final method = paymentMethodLabel(vm.method);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_returned == null) {
          unawaited(_web.canGoBack().then((back) => back ? _web.goBack() : _leave(GatewayOutcome.cancelled)));
        }
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: 'Thanh toán $method',
          onBack: () {
            if (_returned == null) _leave(GatewayOutcome.cancelled);
          },
        ),
        body: Column(
          children: [
            TestId(
              's06g.sandbox',
              child: Container(
                width: double.infinity,
                color: colors.surfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.xs),
                child: Text(
                  'Môi trường thử nghiệm (sandbox) · ${formatVnd(vm.checkout?.amountVnd ?? vm.pricing.totalVnd)}'
                  ' · hết hạn sau $countdown',
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (_progress < 100 && _returned == null) LinearProgressIndicator(value: _progress / 100),
            Expanded(
              child: _returned == null
                  ? WebViewWidget(controller: _web)
                  : TestId(
                      's06g.check',
                      child: ListenableBuilder(
                        listenable: vm.complete,
                        builder: (context, _) => switch (_checkError) {
                          final message? when !vm.complete.running => _CheckFailed(
                            message: message,
                            onRetry: () => unawaited(_check()),
                            onCancel: () => _leave(GatewayOutcome.cancelled),
                          ),
                          _ => LoadingView(message: 'Đang xác nhận thanh toán với $method…'),
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckFailed extends StatelessWidget {
  const _CheckFailed({required this.message, required this.onRetry, required this.onCancel});

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: AppSpacing.md),
                Text(message, textAlign: TextAlign.center, style: text.bodyLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Nếu bạn đã bị trừ tiền, bấm "Kiểm tra lại". Huỷ sẽ huỷ đơn chưa thanh toán và giữ giỏ hàng.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: context.appColors.muted),
                ),
              ],
            ),
          ),
        ),
        BottomActionButton(
          label: 'Kiểm tra lại',
          icon: Icons.refresh,
          testId: 's06g.recheck',
          onPressed: onRetry,
          secondaryLabel: 'Huỷ giao dịch',
          secondaryIcon: Icons.close,
          secondaryTestId: 's06g.cancel',
          onSecondary: onCancel,
        ),
      ],
    );
  }
}
