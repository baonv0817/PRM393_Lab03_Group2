import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_admin/ui/system/vouchers/view_models/admin_vouchers_view_model.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _statusLabel(VoucherStatus status) => switch (status) {
  VoucherStatus.live => 'Đang dùng',
  VoucherStatus.scheduled => 'Chưa bắt đầu',
  VoucherStatus.expired => 'Hết hạn',
  VoucherStatus.off => 'Đã tắt',
};

String _discountLabel(VoucherDiscount discount) => switch (discount) {
  FixedDiscount(:final amountVnd) => 'Giảm ${formatVnd(amountVnd)}',
  PercentDiscount(:final percent, :final maxVnd) => 'Giảm $percent%, tối đa ${formatVnd(maxVnd)}',
};

/// A04: the discount codes, a filter by state, "Thêm mã", "Sửa" and a switch on each.
class AdminVouchersScreen extends StatelessWidget {
  const AdminVouchersScreen({super.key});

  Future<void> _edit(BuildContext context, AdminVouchersViewModel vm, Voucher? voucher) async {
    final isNew = voucher == null;
    final form = await showDialog<VoucherForm>(
      context: context,
      builder: (_) => _VoucherDialog(vm: vm, voucher: voucher),
    );
    if (form == null || !context.mounted) return;
    final result = await vm.save.execute((form: form, isNew: isNew));
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        showAppMessage(context, isNew ? 'Đã thêm mã ${form.code.trim().toUpperCase()}.' : 'Đã lưu mã ${form.code}.');
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  Future<void> _toggle(BuildContext context, AdminVouchersViewModel vm, Voucher voucher, bool active) async {
    final result = await vm.toggle.execute((code: voucher.code, active: active));
    if (!context.mounted || result == null) return;
    if (result case Err(:final error)) showAppMessage(context, error.message);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminVouchersViewModel>();
    return AdminPage(
      title: 'Voucher',
      subtitle: 'Khách thấy các mã đang dùng ở màn chọn voucher (S29).',
      actions: [
        TestId(
          'a04.add',
          child: FilledButton.icon(
            onPressed: () => _edit(context, vm, null),
            icon: const Icon(Icons.add),
            label: const Text('Thêm mã'),
          ),
        ),
      ],
      child: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải mã giảm giá…'),
        ViewError(:final message) => TestId(
          'a04.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'a04.empty',
          child: EmptyView(
            message: message ?? AdminVouchersViewModel.emptyMessage,
            icon: Icons.local_offer_outlined,
            actionLabel: 'Thêm mã',
            onAction: () => _edit(context, vm, null),
          ),
        ),
        ViewData() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final (filter, label) in [
                  (VoucherFilter.all, 'Tất cả'),
                  (VoucherFilter.live, 'Đang dùng'),
                  (VoucherFilter.off, 'Đã tắt'),
                  (VoucherFilter.expired, 'Hết hạn'),
                ])
                  TestId(
                    'a04.filter.${filter.name}',
                    child: AppChip(
                      label: label,
                      selected: vm.filter == filter,
                      onSelected: (_) => vm.setFilter(filter),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: vm.visible.isEmpty
                  ? const EmptyView(message: 'Không có mã nào ở mục này.', icon: Icons.filter_list_off)
                  : ListView.separated(
                      itemCount: vm.visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final voucher = vm.visible[i];
                        return _VoucherRow(
                          vm: vm,
                          voucher: voucher,
                          onEdit: () => _edit(context, vm, voucher),
                          onToggle: (value) => _toggle(context, vm, voucher, value),
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

class _VoucherRow extends StatelessWidget {
  const _VoucherRow({required this.vm, required this.voucher, required this.onEdit, required this.onToggle});

  final AdminVouchersViewModel vm;
  final Voucher voucher;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final status = vm.statusOf(voucher);
    final form = VoucherForm.of(voucher);
    final hours = voucher.activeFrom == null ? '' : ' · ${voucher.activeFrom}–${voucher.activeTo}';
    return TestId(
      'a04.row.${voucher.code}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${voucher.code} · ${voucher.title}',
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${_discountLabel(voucher.discount)} · đơn từ ${formatVnd(voucher.minOrderVnd)}',
                    style: text.bodySmall?.copyWith(color: colors.muted),
                  ),
                  Text(
                    '${form.startsOn == null ? '' : 'Từ ${_day(form.startsOn!)} '}đến ${_day(form.expiresOn!)}$hours',
                    style: text.bodySmall?.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: _statusLabel(status),
              warning: status == VoucherStatus.expired || status == VoucherStatus.off,
            ),
            const SizedBox(width: AppSpacing.sm),
            TestId(
              'a04.switch.${voucher.code}',
              child: Semantics(
                label: 'Bật mã ${voucher.code}',
                toggled: voucher.active,
                child: Switch(value: voucher.active, onChanged: onToggle),
              ),
            ),
            TestId(
              'a04.edit.${voucher.code}',
              child: OutlinedButton(onPressed: onEdit, child: const Text('Sửa')),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherDialog extends StatefulWidget {
  const _VoucherDialog({required this.vm, required this.voucher});

  final AdminVouchersViewModel vm;
  final Voucher? voucher;

  @override
  State<_VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends State<_VoucherDialog> {
  late VoucherForm _form = widget.voucher == null ? const VoucherForm() : VoucherForm.of(widget.voucher!);
  late final _code = TextEditingController(text: _form.code);
  late final _title = TextEditingController(text: _form.title);
  late final _amount = TextEditingController(text: _form.amount);
  late final _percent = TextEditingController(text: _form.percent);
  late final _max = TextEditingController(text: _form.maxVnd);
  late final _min = TextEditingController(text: _form.minOrder);
  late final _from = TextEditingController(text: _form.activeFrom);
  late final _to = TextEditingController(text: _form.activeTo);
  bool _tried = false;

  bool get _isNew => widget.voucher == null;

  @override
  void dispose() {
    for (final c in [_code, _title, _amount, _percent, _max, _min, _from, _to]) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(VoucherForm next) => setState(() => _form = next);

  Future<void> _pickDay({required bool last}) async {
    final today = widget.vm.now;
    final current = last ? _form.expiresOn : _form.startsOn;
    final picked = await showDatePicker(
      context: context,
      initialDate: current == null
          ? DateTime(today.year, today.month, today.day)
          : DateTime(current.year, current.month, current.day),
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
    );
    if (picked == null) return;
    final day = DateTime.utc(picked.year, picked.month, picked.day);
    _update(last ? _form.copyWith(expiresOn: day) : _form.copyWith(startsOn: day));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final problem = widget.vm.problemOf(_form, isNew: _isNew);
    return AlertDialog(
      title: Text(_isNew ? 'Thêm mã giảm giá' : 'Sửa mã ${widget.voucher!.code}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TestId(
                'a04.code',
                child: TextField(
                  controller: _code,
                  enabled: _isNew,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) => _update(_form.copyWith(code: v.toUpperCase())),
                  decoration: InputDecoration(
                    labelText: 'Mã',
                    helperText: _isNew ? 'Chữ in hoa và số, không đổi được sau khi tạo.' : null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TestId(
                'a04.title',
                child: TextField(
                  controller: _title,
                  onChanged: (v) => _update(_form.copyWith(title: v)),
                  decoration: const InputDecoration(labelText: 'Tên chương trình'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TestId(
                'a04.kind',
                child: SegmentedButton<DiscountKind>(
                  segments: const [
                    ButtonSegment(value: DiscountKind.fixed, label: Text('Giảm số tiền')),
                    ButtonSegment(value: DiscountKind.percent, label: Text('Giảm phần trăm')),
                  ],
                  selected: {_form.kind},
                  onSelectionChanged: (s) => _update(_form.copyWith(kind: s.first)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_form.kind == DiscountKind.fixed)
                TestId(
                  'a04.amount',
                  child: TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _update(_form.copyWith(amount: v)),
                    decoration: const InputDecoration(labelText: 'Số tiền giảm (đ)'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TestId(
                        'a04.percent',
                        child: TextField(
                          controller: _percent,
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _update(_form.copyWith(percent: v)),
                          decoration: const InputDecoration(labelText: 'Phần trăm (%)'),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TestId(
                        'a04.max',
                        child: TextField(
                          controller: _max,
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _update(_form.copyWith(maxVnd: v)),
                          decoration: const InputDecoration(labelText: 'Giảm tối đa (đ)'),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              TestId(
                'a04.min',
                child: TextField(
                  controller: _min,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _update(_form.copyWith(minOrder: v)),
                  decoration: const InputDecoration(labelText: 'Đơn tối thiểu (đ)'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TestId(
                      'a04.startsOn',
                      child: OutlinedButton(
                        onPressed: () => _pickDay(last: false),
                        child: Text(_form.startsOn == null ? 'Bắt đầu: ngay' : 'Từ ${_day(_form.startsOn!)}'),
                      ),
                    ),
                  ),
                  if (_form.startsOn != null)
                    IconButton(
                      tooltip: 'Bỏ ngày bắt đầu',
                      onPressed: () => _update(_form.copyWith(startsOn: null)),
                      icon: const Icon(Icons.clear),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TestId(
                      'a04.expiresOn',
                      child: OutlinedButton(
                        onPressed: () => _pickDay(last: true),
                        child: Text(_form.expiresOn == null ? 'Chọn ngày hết hạn' : 'Đến ${_day(_form.expiresOn!)}'),
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
                      'a04.activeFrom',
                      child: TextField(
                        controller: _from,
                        onChanged: (v) => _update(_form.copyWith(activeFrom: v)),
                        decoration: const InputDecoration(labelText: 'Chỉ dùng từ giờ', hintText: '10:15'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TestId(
                      'a04.activeTo',
                      child: TextField(
                        controller: _to,
                        onChanged: (v) => _update(_form.copyWith(activeTo: v)),
                        decoration: const InputDecoration(labelText: 'Đến giờ', hintText: '10:30'),
                      ),
                    ),
                  ),
                ],
              ),
              TestId(
                'a04.active',
                child: SwitchListTile(
                  value: _form.active,
                  onChanged: (v) => _update(_form.copyWith(active: v)),
                  title: const Text('Đang bật'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_tried && problem != null)
                TestId(
                  'a04.error',
                  child: Text(problem, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        TestId(
          'a04.save',
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
