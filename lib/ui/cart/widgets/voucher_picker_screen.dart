import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/cart/view_models/voucher_picker_view_model.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class VoucherPickerScreen extends StatefulWidget {
  const VoucherPickerScreen({super.key});

  @override
  State<VoucherPickerScreen> createState() => _VoucherPickerScreenState();
}

class _VoucherPickerScreenState extends State<VoucherPickerScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _done(Result<void>? result) {
    if (!mounted || result == null) return;
    switch (result) {
      case Ok():
        context.pop();
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  Future<void> _applyCode(VoucherPickerViewModel vm) async {
    FocusScope.of(context).unfocus();
    final result = await vm.applyCode.execute(_code.text);
    if (!mounted || result == null || vm.codeError != null) return;
    _done(result);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VoucherPickerViewModel>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppTopBar(title: 'Mã giảm giá', onBack: () => context.pop()),
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
                Text('Nhập mã', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TestId(
                        's29.code',
                        child: TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                            LengthLimitingTextInputFormatter(20),
                            TextInputFormatter.withFunction(
                              (_, value) => value.copyWith(text: value.text.toUpperCase()),
                            ),
                          ],
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => vm.clearCodeError(),
                          onSubmitted: (_) => _applyCode(vm),
                          decoration: InputDecoration(hintText: 'Nhập mã giảm giá', errorText: vm.codeError),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ListenableBuilder(
                      listenable: vm.applyCode,
                      builder: (context, _) => TestId(
                        's29.apply',
                        child: AppButton(
                          label: 'Áp dụng',
                          variant: AppButtonVariant.secondary,
                          loading: vm.applyCode.running,
                          onPressed: vm.applyCode.running ? null : () => _applyCode(vm),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text('Mã của bạn', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: AppSpacing.xs),
                switch (vm.state) {
                  ViewLoading<List<VoucherOption>>() => const SkeletonList(),
                  ViewEmpty<List<VoucherOption>>(:final message) => TestId(
                    's29.empty',
                    child: EmptyView(
                      message: message ?? VoucherPickerViewModel.emptyMessage,
                      icon: Icons.local_offer_outlined,
                    ),
                  ),
                  ViewError<List<VoucherOption>>(:final message) => TestId(
                    's29.retry',
                    child: ErrorView(message: message, onRetry: vm.load),
                  ),
                  ViewData<List<VoucherOption>>(:final data) => Column(
                    children: [
                      for (final option in data)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _VoucherCard(
                            option: option,
                            condition: vm.conditionOf(option),
                            selected: vm.selected == option.voucher.code,
                            onTap: () => vm.select(option),
                          ),
                        ),
                    ],
                  ),
                },
              ],
            ),
          ),
          ListenableBuilder(
            listenable: vm.confirm,
            builder: (context, _) => BottomActionButton(
              label: vm.confirmLabel,
              testId: 's29.use',
              loading: vm.confirm.running,
              onPressed: vm.canConfirm ? () async => _done(await vm.confirm.execute()) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.option, required this.condition, required this.selected, required this.onTap});

  final VoucherOption option;
  final String condition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final voucher = option.voucher;
    final testId = 's29.voucher.${voucher.code}';
    final expired = option.problem == VoucherProblem.expired || option.problem == VoucherProblem.inactive;

    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.local_offer, color: option.usable ? colors.primaryText : colors.muted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(voucher.code, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xxs),
              Text(voucherBenefit(voucher), style: text.bodyMedium?.copyWith(color: colors.muted)),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                condition,
                style: text.bodyMedium?.copyWith(
                  color: expired ? scheme.error : colors.muted,
                  fontWeight: expired ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (option.usable) {
      return SelectableCard(
        selected: selected,
        onTap: onTap,
        semanticLabel: 'Mã ${voucher.code}. ${voucherBenefit(voucher)}. $condition',
        testId: testId,
        child: info,
      );
    }
    return TestId(
      testId,
      child: Semantics(
        label: 'Mã ${voucher.code}, không dùng được. ${voucherBenefit(voucher)}. $condition',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(child: info),
              SizedBox.square(
                dimension: AppA11y.minTouchTarget,
                child: Icon(expired ? Icons.error : Icons.info_outline, color: expired ? scheme.error : colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
