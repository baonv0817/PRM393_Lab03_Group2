import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_admin/ui/system/kiosks/view_models/admin_kiosks_view_model.dart';
import 'package:breakbite_admin/ui/system/widgets/list_panel.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A02: the kiosks, "Thêm kiosk", and "Sửa" on each one.
class AdminKiosksScreen extends StatelessWidget {
  const AdminKiosksScreen({super.key});

  Future<void> _edit(BuildContext context, AdminKiosksViewModel vm, Kiosk? kiosk) async {
    final isNew = kiosk == null;
    final form = await showDialog<KioskForm>(
      context: context,
      builder: (_) => _KioskDialog(vm: vm, kiosk: kiosk),
    );
    if (form == null || !context.mounted) return;
    final result = await vm.save.execute((form: form, isNew: isNew));
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        showAppMessage(context, isNew ? 'Đã thêm kiosk ${form.name.trim()}.' : 'Đã lưu ${form.name.trim()}.');
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminKiosksViewModel>();
    return AdminPage(
      title: 'Kiosk',
      subtitle: 'Thêm kiosk và sửa mọi thông tin. Nhân viên chỉ đổi phần vận hành hằng ngày (K10).',
      actions: [
        TestId(
          'a02.add',
          child: FilledButton.icon(
            onPressed: () => _edit(context, vm, null),
            icon: const Icon(Icons.add),
            label: const Text('Thêm kiosk'),
          ),
        ),
      ],
      child: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải kiosk…'),
        ViewError(:final message) => TestId(
          'a02.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'a02.empty',
          child: EmptyView(
            message: message ?? AdminKiosksViewModel.emptyMessage,
            icon: Icons.storefront_outlined,
            actionLabel: 'Thêm kiosk',
            onAction: () => _edit(context, vm, null),
          ),
        ),
        ViewData(:final data) => ListPanel(
          itemCount: data.length,
          itemBuilder: (context, i) => _KioskRow(kiosk: data[i], onEdit: () => _edit(context, vm, data[i])),
        ),
      },
    );
  }
}

class _KioskRow extends StatelessWidget {
  const _KioskRow({required this.kiosk, required this.onEdit});

  final Kiosk kiosk;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final hours = kiosk.openTime != null && kiosk.closeTime != null
        ? '${kiosk.openTime}–${kiosk.closeTime}'
        : 'Không giới hạn giờ';
    return TestId(
      'a02.row.${kiosk.id}',
      child: PanelRow(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kiosk.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    '${kiosk.id} · ${kiosk.location.isEmpty ? 'chưa có địa điểm' : kiosk.location}',
                    style: text.bodySmall?.copyWith(color: colors.muted),
                  ),
                  Text(
                    'Giờ $hours · chờ ${kiosk.waitMinutes} phút'
                    '${kiosk.maxOrdersPerSlot == null ? '' : ' · tối đa ${kiosk.maxOrdersPerSlot} đơn mỗi khung'}',
                    style: text.bodySmall?.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              child: Align(
                alignment: Alignment.centerRight,
                child: StatusBadge(label: kiosk.open ? 'Đang nhận đơn' : 'Đóng', warning: !kiosk.open),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TestId(
              'a02.edit.${kiosk.id}',
              child: OutlinedButton(onPressed: onEdit, child: const Text('Sửa')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The form of a kiosk. It returns what was typed; the page saves it and shows the result.
class _KioskDialog extends StatefulWidget {
  const _KioskDialog({required this.vm, required this.kiosk});

  final AdminKiosksViewModel vm;
  final Kiosk? kiosk;

  @override
  State<_KioskDialog> createState() => _KioskDialogState();
}

class _KioskDialogState extends State<_KioskDialog> {
  late final KioskForm _start = widget.kiosk == null ? const KioskForm() : KioskForm.of(widget.kiosk!);
  late final _id = TextEditingController(text: _start.id);
  late final _name = TextEditingController(text: _start.name);
  late final _location = TextEditingController(text: _start.location);
  late final _wait = TextEditingController(text: _start.wait);
  late final _openTime = TextEditingController(text: _start.openTime);
  late final _closeTime = TextEditingController(text: _start.closeTime);
  late final _notice = TextEditingController(text: _start.notice);
  late final _maxOrders = TextEditingController(text: _start.maxOrders);
  late bool _open = _start.open;
  bool _idTouched = false;
  bool _tried = false;

  bool get _isNew => widget.kiosk == null;

  KioskForm get _form => KioskForm(
    id: _id.text,
    name: _name.text,
    location: _location.text,
    open: _open,
    wait: _wait.text,
    openTime: _openTime.text,
    closeTime: _closeTime.text,
    notice: _notice.text,
    maxOrders: _maxOrders.text,
  );

  @override
  void dispose() {
    for (final c in [_id, _name, _location, _wait, _openTime, _closeTime, _notice, _maxOrders]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final problem = widget.vm.problemOf(_form, isNew: _isNew);
    return AlertDialog(
      title: Text(_isNew ? 'Thêm kiosk' : 'Sửa ${widget.kiosk!.name}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TestId(
                'a02.name',
                child: TextField(
                  controller: _name,
                  onChanged: (value) => setState(() {
                    if (_isNew && !_idTouched) _id.text = AdminKiosksViewModel.idFor(value);
                  }),
                  decoration: const InputDecoration(labelText: 'Tên kiosk'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TestId(
                'a02.id',
                child: TextField(
                  controller: _id,
                  enabled: _isNew,
                  onChanged: (_) => setState(() => _idTouched = true),
                  decoration: InputDecoration(
                    labelText: 'Mã kiosk',
                    helperText: _isNew ? 'Không đổi được sau khi tạo.' : null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TestId(
                'a02.location',
                child: TextField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Địa điểm'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TestId(
                      'a02.openTime',
                      child: TextField(
                        controller: _openTime,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Giờ mở', hintText: '06:30'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TestId(
                      'a02.closeTime',
                      child: TextField(
                        controller: _closeTime,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Giờ đóng', hintText: '17:00'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TestId(
                      'a02.wait',
                      child: TextField(
                        controller: _wait,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Chờ (phút)'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TestId(
                      'a02.maxOrders',
                      child: TextField(
                        controller: _maxOrders,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tối đa mỗi khung',
                          helperText: 'Để trống nếu không giới hạn',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TestId(
                'a02.notice',
                child: TextField(
                  controller: _notice,
                  onChanged: (_) => setState(() {}),
                  maxLength: KioskSettings.maxNoticeLength,
                  decoration: const InputDecoration(labelText: 'Thông báo cho khách (không bắt buộc)'),
                ),
              ),
              TestId(
                'a02.open',
                child: SwitchListTile(
                  value: _open,
                  onChanged: (value) => setState(() => _open = value),
                  title: const Text('Đang nhận đơn'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_tried && problem != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TestId(
                    'a02.error',
                    child: Text(problem, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        TestId(
          'a02.save',
          child: FilledButton(
            onPressed: () {
              if (problem != null) {
                setState(() => _tried = true);
                return;
              }
              Navigator.of(context).pop(_form);
            },
            child: const Text('Lưu'),
          ),
        ),
      ],
    );
  }
}
