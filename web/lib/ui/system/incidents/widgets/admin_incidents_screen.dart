import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_admin/ui/system/incidents/view_models/admin_incidents_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

String _typeText(IncidentType type) => switch (type) {
  IncidentType.wrongItem => 'Sai món',
  IncidentType.missingItem => 'Thiếu món',
  IncidentType.quality => 'Chất lượng',
  IncidentType.late => 'Giao trễ',
  IncidentType.other => 'Khác',
};

String _statusText(IncidentStatus status) => switch (status) {
  IncidentStatus.open => 'Mới',
  IncidentStatus.inProgress => 'Đang xử lý',
  IncidentStatus.resolved => 'Đã xử lý',
};

String _answerText(Incident i) => switch (i.resolution) {
  IncidentResolution.refunded => 'Hoàn tiền${i.refundVnd == null ? '' : ' ${formatVnd(i.refundVnd!)}'}',
  IncidentResolution.rejected => 'Từ chối${i.resolutionNote == null ? '' : ': ${i.resolutionNote}'}',
  null => '',
};

/// A07: the reports of customers across the kiosks, filtered by state and kiosk. Read-only.
class AdminIncidentsScreen extends StatelessWidget {
  const AdminIncidentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminIncidentsViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return AdminPage(
      title: 'Sự cố',
      subtitle: vm.overdue == 0
          ? 'Khách báo thiếu món, sai món, chất lượng. Nhân viên kiosk xử lý (K13).'
          : '${vm.overdue} sự cố chưa được trả lời quá một ngày.',
      child: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải sự cố…'),
        ViewError(:final message) => TestId(
          'a07.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'a07.empty',
          child: EmptyView(message: message ?? AdminIncidentsViewModel.emptyMessage, icon: Icons.thumb_up_outlined),
        ),
        ViewData() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 260,
                  child: TestId(
                    'a07.kiosk',
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: vm.kioskId,
                      decoration: const InputDecoration(labelText: 'Kiosk'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Mọi kiosk')),
                        for (final k in vm.kiosks) DropdownMenuItem<String?>(value: k.id, child: Text(k.name)),
                      ],
                      onChanged: vm.setKiosk,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    TestId(
                      'a07.status.all',
                      child: AppChip(
                        label: 'Tất cả',
                        selected: vm.status == null,
                        onSelected: (_) => vm.setStatus(null),
                      ),
                    ),
                    for (final status in IncidentStatus.values)
                      TestId(
                        'a07.status.${status.name}',
                        child: AppChip(
                          label: '${_statusText(status)} (${vm.countOf(status)})',
                          selected: vm.status == status,
                          onSelected: (_) => vm.setStatus(status),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: vm.visible.isEmpty
                  ? const EmptyView(message: 'Không có sự cố nào ở mục này.', icon: Icons.filter_list_off)
                  : ListView.separated(
                      itemCount: vm.visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final incident = vm.visible[i];
                        return TestId(
                          'a07.row.${incident.id}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_typeText(incident.type)} · đơn ${incident.orderId}',
                                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      Text(incident.description, style: text.bodyMedium),
                                      Text(
                                        '${incident.customerName.isEmpty ? 'Khách' : incident.customerName} · ${vm.kioskName(incident.kioskId)} · ${formatDateTime(incident.createdAt)}',
                                        style: text.bodySmall?.copyWith(color: colors.muted),
                                      ),
                                      if (incident.status == IncidentStatus.resolved)
                                        Text('Trả lời: ${_answerText(incident)}', style: text.bodySmall),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  label: _statusText(incident.status),
                                  warning: incident.status == IncidentStatus.open,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      },
    );
  }
}
