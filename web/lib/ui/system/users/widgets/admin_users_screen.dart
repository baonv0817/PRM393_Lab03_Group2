import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_admin/ui/system/admin_labels.dart';
import 'package:breakbite_admin/ui/system/users/view_models/admin_users_view_model.dart';
import 'package:breakbite_admin/ui/system/widgets/list_panel.dart';
import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A01: the accounts, a search box, a filter by role, and "Phân quyền" on each row.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit(AdminUsersViewModel vm, AppUser user) async {
    final change = await showDialog<AccessChange>(
      context: context,
      builder: (_) => _AccessDialog(vm: vm, user: user),
    );
    if (change == null || !mounted) return;
    final result = await vm.setAccess.execute(change);
    if (!mounted || result == null) return;
    switch (result) {
      case Ok():
        showAppMessage(context, 'Đã đặt ${user.displayName} thành ${roleLabel(change.role).toLowerCase()}.');
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminUsersViewModel>();
    final text = Theme.of(context).textTheme;
    return AdminPage(
      title: 'Người dùng',
      subtitle:
          '${vm.countOf(UserRole.user)} khách · ${vm.countOf(UserRole.staff)} nhân viên · '
          '${vm.countOf(UserRole.admin)} quản trị',
      child: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải tài khoản…'),
        ViewError(:final message) => TestId(
          'a01.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => EmptyView(
          message: message ?? AdminUsersViewModel.emptyMessage,
          icon: Icons.people_outline,
        ),
        ViewData() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TestId(
              'a01.search',
              child: AppSearchField(hint: 'Tìm theo tên hoặc email', controller: _search, onChanged: vm.setQuery),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                TestId(
                  'a01.filter.all',
                  child: AppChip(
                    label: 'Tất cả',
                    selected: vm.roleFilter == null,
                    onSelected: (_) => vm.setRoleFilter(null),
                  ),
                ),
                for (final role in UserRole.values)
                  TestId(
                    'a01.filter.${role.name}',
                    child: AppChip(
                      label: roleLabel(role),
                      selected: vm.roleFilter == role,
                      onSelected: (_) => vm.setRoleFilter(role),
                    ),
                  ),
              ],
            ),
            if (vm.truncated) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Chỉ hiện ${AdminUserRepository.maxUsers} tài khoản đầu tiên.',
                style: text.bodySmall?.copyWith(color: context.appColors.muted),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: vm.visible.isEmpty
                  ? const EmptyView(message: AdminUsersViewModel.noMatchMessage, icon: Icons.search_off)
                  : ListPanel(
                      itemCount: vm.visible.length,
                      itemBuilder: (context, i) => _UserRow(vm: vm, user: vm.visible[i], onEdit: _edit),
                    ),
            ),
          ],
        ),
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.vm, required this.user, required this.onEdit});

  final AdminUsersViewModel vm;
  final AppUser user;
  final Future<void> Function(AdminUsersViewModel, AppUser) onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final self = vm.isSelf(user);
    return TestId(
      'a01.row.${user.uid}',
      child: PanelRow(
        child: Row(
          children: [
            UserAvatar(name: user.displayName, photoUrl: user.photoUrl, size: 40),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    self ? '${user.displayName} (bạn)' : user.displayName,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.email ?? '',
                    style: text.bodySmall?.copyWith(color: colors.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 170,
              child: Text(
                user.kioskId == null ? '' : vm.kioskName(user.kioskId),
                style: text.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 112,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(label: roleLabel(user.role), warning: user.role == UserRole.admin),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TestId(
              'a01.edit.${user.uid}',
              child: OutlinedButton(onPressed: self ? null : () => onEdit(vm, user), child: const Text('Phân quyền')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dialog that picks a role (and a kiosk for staff). It returns the change, the page saves it.
class _AccessDialog extends StatefulWidget {
  const _AccessDialog({required this.vm, required this.user});

  final AdminUsersViewModel vm;
  final AppUser user;

  @override
  State<_AccessDialog> createState() => _AccessDialogState();
}

class _AccessDialogState extends State<_AccessDialog> {
  late UserRole _role = widget.user.role;
  late String? _kiosk = widget.user.kioskId ?? widget.vm.kiosks.firstOrNull?.id;

  AccessChange get _change =>
      AccessChange(uid: widget.user.uid, role: _role, kioskId: _role == UserRole.staff ? _kiosk : null);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final problem = widget.vm.problemOf(_change);
    final unchanged = _role == widget.user.role && (_role != UserRole.staff || _kiosk == widget.user.kioskId);
    return AlertDialog(
      title: Text('Phân quyền cho ${widget.user.displayName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.user.email ?? '', style: text.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<UserRole>(
              groupValue: _role,
              onChanged: (value) => setState(() => _role = value ?? _role),
              child: Column(
                children: [
                  for (final role in UserRole.values)
                    TestId(
                      'a01.role.${role.name}',
                      child: RadioListTile<UserRole>(value: role, title: Text(roleLabel(role)), dense: true),
                    ),
                ],
              ),
            ),
            if (_role == UserRole.staff) ...[
              const SizedBox(height: AppSpacing.xs),
              TestId(
                'a01.kiosk',
                child: DropdownButtonFormField<String>(
                  initialValue: widget.vm.kiosks.any((k) => k.id == _kiosk) ? _kiosk : null,
                  decoration: const InputDecoration(labelText: 'Kiosk của nhân viên'),
                  items: [for (final k in widget.vm.kiosks) DropdownMenuItem(value: k.id, child: Text(k.name))],
                  onChanged: (value) => setState(() => _kiosk = value),
                ),
              ),
            ],
            if (problem != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(problem, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        TestId(
          'a01.save',
          child: FilledButton(
            onPressed: problem != null || unchanged ? null : () => Navigator.of(context).pop(_change),
            child: const Text('Lưu'),
          ),
        ),
      ],
    );
  }
}
