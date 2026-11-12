import 'package:breakbite/ui/profile/view_models/payment_settings_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class PaymentSettingsScreen extends StatelessWidget {
  const PaymentSettingsScreen({super.key});

  Future<void> _save(BuildContext context, PaymentSettingsViewModel vm) async {
    final result = await vm.save.execute();
    if (!context.mounted || result == null) return;
    final message = switch (result) {
      Ok(:final value) => 'Đã đặt ${paymentMethodLabel(value)} làm mặc định.',
      Err(:final error) => error.message,
    };
    showAppMessage(context, message);
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
                    PaymentMethodTile(
                      testId: 's17.method.${method.name}',
                      method: method,
                      selected: vm.chosen == method,
                      onTap: () => vm.choose(method),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            ListenableBuilder(
              listenable: vm.save,
              builder: (context, _) => BottomActionButton(
                label: 'Lưu mặc định',
                testId: 's17.save',
                loading: vm.save.running,
                onPressed: vm.hasChanges ? () => _save(context, vm) : null,
              ),
            ),
          ],
        ),
      },
    );
  }
}
