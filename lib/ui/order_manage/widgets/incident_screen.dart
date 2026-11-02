import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/order_manage/view_models/incident_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S24: tell the kiosk what went wrong with an order, then follow how it is handled.
class IncidentScreen extends StatelessWidget {
  const IncidentScreen({super.key});

  void _back(BuildContext context, IncidentViewModel vm) =>
      context.canPop() ? context.pop() : context.go(AppRoutes.orderDetailOf(vm.orderId));

  Future<void> _submit(BuildContext context, IncidentViewModel vm) async {
    final result = await vm.submit.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        showAppMessage(context, 'Đã gửi báo cáo. Kiosk sẽ xem sớm.');
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IncidentViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Báo sự cố', onBack: () => _back(context, vm)),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn hàng…'),
        ViewError(:final message) => TestId(
          's24.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          's24.empty',
          child: EmptyView(
            message: message ?? IncidentViewModel.notFoundMessage,
            actionLabel: 'Xem đơn hàng',
            onAction: () => context.go(AppRoutes.orders),
          ),
        ),
        ViewData(:final data) =>
          vm.incident == null
              ? _Form(vm: vm, order: data, onSubmit: () => _submit(context, vm))
              : _SentReport(vm: vm, order: data, onBack: () => _back(context, vm)),
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.vm, required this.order, required this.onSubmit});

  final IncidentViewModel vm;
  final Order order;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final hint = vm.missingHint;
    return Column(
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
              TestId(
                's24.header',
                child: ProfileSection(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đơn #${order.orderCode} · ${order.kioskName}',
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(orderItemsSummary(order), style: text.bodyMedium?.copyWith(color: colors.muted)),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
                child: Semantics(
                  header: true,
                  child: Text('Bạn gặp vấn đề gì?', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ),
              for (final type in IncidentViewModel.types)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: SelectableCard(
                    testId: 's24.type.${type.name}',
                    selected: vm.type == type,
                    semanticLabel: incidentTypeLabel(type),
                    onTap: () => vm.selectType(type),
                    child: Text(incidentTypeLabel(type), style: text.bodyLarge),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              TestId(
                's24.description',
                child: TextField(
                  onChanged: vm.setDescription,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: IncidentViewModel.maxDescriptionLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả sự cố',
                    hintText: 'Ví dụ: thiếu 1 ly trà đào trong đơn',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: TestId(
                    's24.hint',
                    child: Text(hint, style: text.bodyMedium?.copyWith(color: colors.muted)),
                  ),
                ),
            ],
          ),
        ),
        ListenableBuilder(
          listenable: vm.submit,
          builder: (context, _) => BottomActionButton(
            label: 'Gửi báo cáo',
            testId: 's24.submit',
            loading: vm.submit.running,
            onPressed: vm.canSubmit && !vm.submit.running ? onSubmit : null,
          ),
        ),
      ],
    );
  }
}

class _SentReport extends StatelessWidget {
  const _SentReport({required this.vm, required this.order, required this.onBack});

  final IncidentViewModel vm;
  final Order order;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final incident = vm.incident!;
    final resolution = vm.resolutionLine;
    final refunded = incident.resolution == IncidentResolution.refunded;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      children: [
        TestId(
          's24.report',
          child: ProfileSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đơn #${order.orderCode} · ${order.kioskName}',
                    style: text.bodyMedium?.copyWith(color: colors.muted),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(vm.typeLabel, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TestId('s24.status', child: StatusBadge(label: vm.statusLabel)),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(incident.description, style: text.bodyLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(vm.sentAtLine, style: text.bodyMedium?.copyWith(color: colors.muted)),
                ],
              ),
            ),
          ),
        ),
        if (resolution != null) ...[
          const SizedBox(height: AppSpacing.md),
          TestId(
            's24.resolution',
            child: ProfileSection(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      refunded ? Icons.check_circle_outline : Icons.info_outline,
                      color: refunded ? colors.success : scheme.error,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(resolution, style: text.bodyLarge)),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Mỗi đơn gửi được một báo cáo. Kiosk sẽ trả lời ngay tại đây.',
            style: text.bodyMedium?.copyWith(color: colors.muted),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TestId(
          's24.back',
          child: AppButton(label: 'Quay lại đơn', variant: AppButtonVariant.secondary, large: true, onPressed: onBack),
        ),
      ],
    );
  }
}
