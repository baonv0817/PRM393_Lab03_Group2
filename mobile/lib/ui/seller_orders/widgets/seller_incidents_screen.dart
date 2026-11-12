import 'package:breakbite/ui/seller_orders/view_models/seller_incidents_view_model.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_order_parts.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// K13: reports from customers. Each card shows what was reported and for which order; staff take it on,
/// refund the order or turn the report down with a reason that the customer reads in S24.
class SellerIncidentsScreen extends StatelessWidget {
  const SellerIncidentsScreen({super.key});

  Future<void> _run(BuildContext context, Future<Result<void>> action, String done) async {
    final result = await action;
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        showAppMessage(context, done);
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  Future<void> _refund(BuildContext context, SellerIncidentsViewModel vm, Incident incident) async {
    final max = vm.maxRefundOf(incident);
    if (max == null) {
      showAppMessage(context, 'Đang tải đơn, thử lại sau giây lát.');
      return;
    }
    final ok = await showAppDialog(
      context,
      title: 'Hoàn ${formatVnd(max)}?',
      message: 'Khách được hoàn toàn bộ số tiền của đơn #${incident.orderId}.',
      confirmLabel: 'Hoàn tiền',
      cancelLabel: 'Quay lại',
    );
    if (ok != true || !context.mounted) return;
    await _run(context, vm.refund(incident), 'Đã hoàn ${formatVnd(max)} cho khách.');
  }

  Future<void> _reject(BuildContext context, SellerIncidentsViewModel vm, Incident incident) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _RejectReportDialog());
    if (reason == null || !context.mounted) return;
    await _run(context, vm.rejectReport(incident, reason), 'Đã từ chối kèm lý do.');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellerIncidentsViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Sự cố từ khách', onBack: () => context.canPop() ? context.pop() : null),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải sự cố…'),
        ViewError(:final message) => TestId(
          'k13.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'k13.empty',
          child: EmptyView(
            message: message ?? SellerIncidentsViewModel.emptyMessage,
            icon: Icons.thumb_up_alt_outlined,
          ),
        ),
        ViewData(:final data) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                for (final incident in data)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _IncidentCard(
                      incident: incident,
                      order: vm.orderOf(incident),
                      busy: vm.busyId == incident.orderId,
                      onTake: () => _run(context, vm.take(incident), 'Bạn đang xử lý sự cố này.'),
                      onRefund: () => _refund(context, vm, incident),
                      onReject: () => _reject(context, vm, incident),
                    ),
                  ),
              ],
            ),
          ),
        ),
      },
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.incident,
    required this.order,
    required this.busy,
    required this.onTake,
    required this.onRefund,
    required this.onReject,
  });

  final Incident incident;
  final Order? order;
  final bool busy;
  final VoidCallback onTake;
  final VoidCallback onRefund;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final resolved = incident.status == IncidentStatus.resolved;
    final id = incident.orderId;
    return TestId(
      'k13.incident.$id',
      child: SellerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(child: StatusBadge(label: incidentTypeLabel(incident.type))),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  resolved
                      ? (incident.resolution == IncidentResolution.refunded ? 'Đã hoàn tiền' : 'Đã từ chối')
                      : (incident.status == IncidentStatus.inProgress ? 'Đang xử lý' : 'Mới'),
                  style: text.labelLarge?.copyWith(
                    color: resolved ? colors.success : colors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Gửi ${formatTime(incident.createdAt)} · Đơn #$id',
              style: text.bodyMedium?.copyWith(color: colors.muted),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('"${incident.description}"', style: text.bodyLarge),
            if (order != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(orderItemsSummary(order!), style: text.bodyMedium?.copyWith(color: colors.muted)),
              Text(orderPaymentLabel(order!), style: text.bodyMedium?.copyWith(color: colors.muted)),
            ],
            if (resolved) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                incident.resolution == IncidentResolution.refunded
                    ? 'Hoàn ${formatVnd(incident.refundVnd ?? 0)}'
                    : 'Lý do: ${incident.resolutionNote ?? ''}',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              if (incident.status == IncidentStatus.open) ...[
                TestId(
                  'k13.take.$id',
                  child: AppButton(
                    label: 'Nhận xử lý',
                    variant: AppButtonVariant.secondary,
                    large: true,
                    loading: busy,
                    onPressed: onTake,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              TestId(
                'k13.refund.$id',
                child: AppButton(
                  label: order == null ? 'Hoàn tiền' : 'Hoàn tiền ${formatVnd(order!.totalVnd)}',
                  loading: busy,
                  onPressed: busy ? null : onRefund,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TestId(
                'k13.reject.$id',
                child: AppButton(
                  label: 'Từ chối và giải thích',
                  variant: AppButtonVariant.secondary,
                  large: true,
                  onPressed: busy ? null : onReject,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RejectReportDialog extends StatefulWidget {
  const _RejectReportDialog();

  @override
  State<_RejectReportDialog> createState() => _RejectReportDialogState();
}

class _RejectReportDialogState extends State<_RejectReportDialog> {
  final _reason = TextEditingController();
  var _tried = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empty = _reason.text.trim().isEmpty;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
      title: const Text('Từ chối sự cố'),
      content: TestId(
        'k13.reason',
        child: AppTextField(
          label: 'Lý do gửi cho khách',
          controller: _reason,
          errorText: _tried && empty ? 'Nhập lý do để khách biết.' : null,
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        AppButton(label: 'Quay lại', variant: AppButtonVariant.secondary, onPressed: () => Navigator.of(context).pop()),
        TestId(
          'k13.reason.send',
          child: AppButton(
            label: 'Gửi lý do',
            onPressed: () {
              if (empty) {
                setState(() => _tried = true);
                return;
              }
              Navigator.of(context).pop(_reason.text.trim());
            },
          ),
        ),
      ],
    );
  }
}
