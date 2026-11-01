import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/profile/view_models/payment_settings_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class PaymentSettingsScreen extends StatelessWidget {
  const PaymentSettingsScreen({super.key});

  static const _details = {
    PaymentMethod.momo: (icon: Icons.account_balance_wallet, subtitle: 'Ví điện tử'),
    PaymentMethod.vnpay: (icon: Icons.qr_code_2, subtitle: 'Quét mã bằng app ngân hàng'),
    PaymentMethod.card: (icon: Icons.credit_card, subtitle: 'Trừ vào thẻ sinh viên'),
    PaymentMethod.cash: (icon: Icons.payments_outlined, subtitle: 'Trả khi nhận món tại kiosk'),
  };

  Future<void> _save(BuildContext context, PaymentSettingsViewModel vm) async {
    final result = await vm.save.execute();
    if (!context.mounted || result == null) return;
    final message = switch (result) {
      Ok(:final value) => 'Đã đặt ${paymentMethodLabel(value)} làm mặc định.',
      Err(:final error) => error.message,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PaymentSettingsViewModel>();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppTopBar(title: 'Phương thức thanh toán', onBack: () => context.pop()),
      body: switch (vm.saved) {
        ViewLoading() || ViewEmpty() => const LoadingView(message: 'Đang tải cài đặt…'),
        ViewError(:final message) => TestId(
          's17.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewData() => Column(
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
                  Text('Chọn cách trả mặc định', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.xs),
                  for (final method in PaymentMethod.values) ...[
                    _MethodCard(
                      method: method,
                      icon: _details[method]!.icon,
                      subtitle: _details[method]!.subtitle,
                      selected: vm.chosen == method,
                      onTap: () => vm.choose(method),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.xs,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ListenableBuilder(
                    listenable: vm.save,
                    builder: (context, _) => TestId(
                      's17.save',
                      child: AppButton(
                        label: 'Lưu mặc định',
                        loading: vm.save.running,
                        onPressed: vm.hasChanges ? () => _save(context, vm) : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      },
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.icon,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final IconData icon;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final label = paymentMethodLabel(method);
    return TestId(
      's17.method.${method.name}',
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: '$label. $subtitle',
        excludeSemantics: true,
        child: Material(
          color: selected ? colors.selected : scheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: selected ? scheme.primary : colors.border, width: selected ? 1.5 : 1),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Icon(icon, color: colors.primaryText),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        Text(subtitle, style: text.bodyMedium?.copyWith(color: colors.muted)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: AppA11y.minTouchTarget,
                    height: AppA11y.minTouchTarget,
                    child: Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? scheme.primary : colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
