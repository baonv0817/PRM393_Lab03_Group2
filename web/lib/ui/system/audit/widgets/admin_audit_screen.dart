import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_admin/ui/system/audit/view_models/admin_audit_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _actionLabels = {
  AuditAction.userAccess: 'Người dùng',
  AuditAction.kioskSave: 'Kiosk',
  AuditAction.slotsCreate: 'Khung giờ',
  AuditAction.voucherSave: 'Voucher',
  AuditAction.announcementSave: 'Thông báo',
  AuditAction.catalogCopy: 'Chép món',
};

/// A10: the audit log.
class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminAuditViewModel>();
    final text = Theme.of(context).textTheme;
    return AdminPage(
      title: 'Nhật ký',
      subtitle: '200 thay đổi gần nhất trên trang quản trị: ai làm gì, lúc nào.',
      child: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải nhật ký…'),
        ViewError(:final message) => TestId(
          'a10.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'a10.empty',
          child: EmptyView(message: message ?? AdminAuditViewModel.emptyMessage, icon: Icons.history),
        ),
        ViewData() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TestId(
              'a10.search',
              child: AppSearchField(
                controller: _search,
                hint: 'Tìm theo người làm, đối tượng hoặc nội dung',
                onChanged: vm.setSearch,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                TestId(
                  'a10.action.all',
                  child: AppChip(label: 'Tất cả', selected: vm.action == null, onSelected: (_) => vm.setAction(null)),
                ),
                for (final e in _actionLabels.entries)
                  TestId(
                    'a10.action.${e.key}',
                    child: AppChip(
                      label: e.value,
                      selected: vm.action == e.key,
                      onSelected: (_) => vm.setAction(e.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: vm.visible.isEmpty
                  ? const EmptyView(message: 'Không có dòng nào khớp.', icon: Icons.search_off)
                  : ListView.separated(
                      itemCount: vm.visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = vm.visible[i];
                        return TestId(
                          'a10.row.${e.id}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.summary, style: text.bodyMedium),
                                Text(
                                  '${e.actorName.isEmpty ? e.actorUid : e.actorName} · ${formatDateTime(e.at)} · ${e.target}',
                                  style: text.bodySmall?.copyWith(color: context.appColors.muted),
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
