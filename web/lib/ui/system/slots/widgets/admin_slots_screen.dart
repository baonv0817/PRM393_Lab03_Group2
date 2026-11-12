import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_admin/ui/system/slots/view_models/admin_slots_view_model.dart';
import 'package:breakbite_admin/ui/system/widgets/list_panel.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A03: the pickup windows of one kiosk on the left, the form that makes the next days on the right.
class AdminSlotsScreen extends StatelessWidget {
  const AdminSlotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminSlotsViewModel>();
    return AdminPage(
      title: 'Khung giờ nhận món',
      subtitle: 'Khách chọn giờ nhận món ở S25. Tạo trước các ngày tới để danh sách giờ không bị trống.',
      child: !vm.kiosksLoaded
          ? const LoadingView(message: 'Đang tải kiosk…')
          : vm.kiosks.isEmpty
          ? const EmptyView(message: AdminSlotsViewModel.noKioskMessage, icon: Icons.storefront_outlined)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _SlotList(vm: vm)),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(width: 360, child: _Generator(vm: vm)),
              ],
            ),
    );
  }
}

class _SlotList extends StatelessWidget {
  const _SlotList({required this.vm});

  final AdminSlotsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TestId(
          'a03.kiosk',
          child: DropdownButtonFormField<String>(
            initialValue: vm.kioskId,
            decoration: const InputDecoration(labelText: 'Kiosk'),
            items: [for (final k in vm.kiosks) DropdownMenuItem(value: k.id, child: Text(k.name))],
            onChanged: (value) {
              if (value != null) vm.selectKiosk(value);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: switch (vm.state) {
            ViewLoading() => const LoadingView(message: 'Đang tải khung giờ…'),
            ViewError(:final message) => ErrorView(message: message, onRetry: vm.load),
            ViewEmpty(:final message) => TestId(
              'a03.empty',
              child: EmptyView(message: message ?? AdminSlotsViewModel.emptyMessage, icon: Icons.schedule),
            ),
            ViewData(:final data) => ListPanel(
              itemCount: data.length,
              itemBuilder: (context, i) {
                final slot = data[i];
                final newDay = i == 0 || formatDate(data[i - 1].startAt) != formatDate(slot.startAt);
                return TestId(
                  'a03.slot.${slot.id}',
                  child: PanelRow(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(newDay ? formatDate(slot.startAt) : '', style: text.titleSmall),
                        ),
                        Expanded(child: Text('${formatTime(slot.startAt)} – ${formatTime(slot.endAt)}')),
                        Text(
                          '${slot.booked}/${slot.capacity} đơn',
                          style: text.bodyMedium?.copyWith(
                            color: slot.isFull ? Theme.of(context).colorScheme.error : colors.muted,
                          ),
                        ),
                        if (slot.isFull) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const StatusBadge(label: 'Đầy', warning: true),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          },
        ),
      ],
    );
  }
}

class _Generator extends StatefulWidget {
  const _Generator({required this.vm});

  final AdminSlotsViewModel vm;

  @override
  State<_Generator> createState() => _GeneratorState();
}

class _GeneratorState extends State<_Generator> {
  late final _days = TextEditingController(text: widget.vm.days);
  late final _minutes = TextEditingController(text: widget.vm.slotMinutes);
  late final _capacity = TextEditingController(text: widget.vm.capacity);
  final _newBreak = TextEditingController();

  @override
  void dispose() {
    _days.dispose();
    _minutes.dispose();
    _capacity.dispose();
    _newBreak.dispose();
    super.dispose();
  }

  Future<void> _make() async {
    final result = await widget.vm.create.execute();
    if (!mounted || result == null) return;
    switch (result) {
      case Ok(:final value):
        showAppMessage(
          context,
          value.created == 0
              ? 'Các khung giờ này đã có sẵn, không tạo thêm.'
              : 'Đã tạo ${value.created} khung giờ mới${value.existing > 0 ? ' (${value.existing} khung đã có, giữ nguyên)' : ''}.',
        );
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final problem = vm.problem;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tạo khung giờ', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          TestId(
            'a03.days',
            child: TextField(
              controller: _days,
              onChanged: vm.setDays,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số ngày tới',
                helperText: 'Tính từ hôm nay, bỏ thứ Bảy và Chủ nhật',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TestId(
                  'a03.minutes',
                  child: TextField(
                    controller: _minutes,
                    onChanged: vm.setSlotMinutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Mỗi khung (phút)'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TestId(
                  'a03.capacity',
                  child: TextField(
                    controller: _capacity,
                    onChanged: vm.setCapacity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sức chứa (đơn)'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Giờ ra chơi', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final time in vm.breakStarts)
                TestId(
                  'a03.break.${time.replaceAll(':', '')}',
                  child: InputChip(label: Text(time), onDeleted: () => vm.removeBreak(time)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: TestId(
                  'a03.newBreak',
                  child: TextField(
                    controller: _newBreak,
                    decoration: const InputDecoration(labelText: 'Thêm giờ', hintText: '15:30'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              TestId(
                'a03.addBreak',
                child: OutlinedButton(
                  onPressed: () {
                    vm.addBreak(_newBreak.text);
                    _newBreak.clear();
                  },
                  child: const Text('Thêm'),
                ),
              ),
            ],
          ),
          TextButton(onPressed: vm.resetBreaks, child: const Text('Dùng giờ mặc định')),
          const SizedBox(height: AppSpacing.sm),
          if (problem != null)
            TestId(
              'a03.problem',
              child: Text(problem, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
            )
          else
            TestId(
              'a03.preview',
              child: Text(
                'Sẽ tạo tối đa ${vm.planned} khung giờ, khung nào đã có thì giữ nguyên.',
                style: text.bodySmall?.copyWith(color: colors.muted),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          ListenableBuilder(
            listenable: vm.create,
            builder: (context, _) => TestId(
              'a03.create',
              child: AppButton(
                label: 'Tạo khung giờ',
                icon: Icons.add_alarm,
                loading: vm.create.running,
                onPressed: problem != null || vm.create.running ? null : _make,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
