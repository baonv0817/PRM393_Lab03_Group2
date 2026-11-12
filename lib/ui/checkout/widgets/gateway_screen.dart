import 'dart:async';

import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/checkout/view_models/checkout_view_model.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  Timer? _ticker;
  bool _finished = false;

  CheckoutViewModel get _vm => context.read<CheckoutViewModel>();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _finished) return;
    final deadline = _vm.gatewayDeadline;
    if (deadline != null && !_vm.now.isBefore(deadline)) {
      _leave(GatewayOutcome.expired);
    } else {
      setState(() {});
    }
  }

  void _leave(GatewayOutcome outcome) {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    _vm.failGateway(outcome);
    if (context.canPop()) context.pop();
  }

  Future<void> _pay() async {
    final router = GoRouter.of(context);
    final result = await _vm.place.execute();
    if (result == null) return;
    switch (result) {
      case Ok(:final value):
        _finished = true;
        _ticker?.cancel();
        router.go(AppRoutes.orderOf(value));
      case Err(:final error):
        if (mounted) showAppMessage(context, error.message);
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

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: text.bodyMedium?.copyWith(color: colors.muted)),
          ),
          Text(value, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(GatewayOutcome.cancelled);
      },
      child: Scaffold(
        appBar: AppTopBar(title: 'Cổng thanh toán', onBack: () => _leave(GatewayOutcome.cancelled)),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Mô phỏng cổng thanh toán bên thứ ba',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TestId(
                    's06g.summary',
                    child: ProfileSection(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Số tiền thanh toán', style: text.bodyMedium?.copyWith(color: colors.muted)),
                            Text(
                              formatVnd(vm.pricing.totalVnd),
                              style: text.headlineMedium?.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
                            ),
                            Divider(height: AppSpacing.lg, color: colors.border),
                            row('Phương thức', paymentMethodLabel(vm.method)),
                            row('Nhận tại', vm.kiosk?.name ?? 'kiosk'),
                            TestId('s06g.countdown', child: row('Hết hạn sau', countdown)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Xác nhận giao dịch để hoàn tất đơn. Nếu từ chối, giỏ hàng vẫn được giữ.',
                    style: text.bodyMedium?.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: vm.place,
              builder: (context, _) => BottomActionButton(
                label: 'Xác nhận thanh toán',
                icon: Icons.lock_outline,
                testId: 's06g.pay',
                loading: vm.place.running,
                onPressed: vm.place.running ? null : _pay,
                secondaryLabel: 'Từ chối giao dịch',
                secondaryIcon: Icons.close,
                secondaryTestId: 's06g.decline',
                onSecondary: () => _leave(GatewayOutcome.declined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
