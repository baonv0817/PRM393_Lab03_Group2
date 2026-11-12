import 'package:breakbite_admin/ui/review_queue/view_models/review_queue_view_model.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_admin/ui/shell/widgets/admin_page.dart';
import 'package:breakbite_core/data/repositories/order_repository.dart';
import 'package:breakbite_core/domain/models/order.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:breakbite_core/ui/core/widgets/inputs.dart';
import 'package:breakbite_core/ui/core/widgets/state_views.dart';
import 'package:breakbite_core/ui/core/widgets/status_badge.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// W03 Review queue (list on the left, the selected order on the right).
class ReviewQueueScreen extends StatelessWidget {
  const ReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        ReviewQueueViewModel(orders: context.read<OrderRepository>(), kioskId: context.read<AdminSession>().kioskId!),
    child: const _ReviewQueueView(),
  );
}

class _ReviewQueueView extends StatefulWidget {
  const _ReviewQueueView();

  @override
  State<_ReviewQueueView> createState() => _ReviewQueueViewState();
}

class _ReviewQueueViewState extends State<_ReviewQueueView> {
  late final ReviewQueueViewModel _vm = context.read<ReviewQueueViewModel>();

  @override
  void initState() {
    super.initState();
    _vm.approve.addListener(_onApproved);
    _vm.reject.addListener(_onRejected);
  }

  @override
  void dispose() {
    _vm.approve.removeListener(_onApproved);
    _vm.reject.removeListener(_onRejected);
    super.dispose();
  }

  void _onApproved() =>
      showCommandResult(context, _vm.approve, success: 'Đã duyệt đơn. Khách thấy ngay trên ứng dụng.');
  void _onRejected() => showCommandResult(context, _vm.reject, success: 'Đã từ chối đơn và gửi lý do cho khách.');

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewQueueViewModel>();
    final waiting = vm.state.dataOrNull?.length ?? 0;
    return AdminPage(
      title: 'Duyệt đơn',
      subtitle: 'Đơn khách vừa đặt trên ứng dụng · $waiting chờ duyệt · ${vm.inProgressCount} đang làm',
      child: ViewStateView<List<Order>>(
        state: vm.state,
        onRetry: vm.retry,
        builder: (context, orders) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) => _OrderTile(
                  order: orders[i],
                  selected: orders[i].id == vm.selected?.id,
                  onTap: () => vm.select(orders[i]),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: 4, child: vm.selected == null ? const SizedBox.shrink() : _OrderDetail(order: vm.selected!)),
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.selected, required this.onTap});

  final Order order;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final count = order.items.fold<int>(0, (sum, line) => sum + line.quantity);
    return Semantics(
      selected: selected,
      button: true,
      label: 'Đơn ${order.orderCode} của ${order.customerName}',
      child: Card(
        color: selected ? colors.selected : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: selected ? colors.selectedBorder : colors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${order.orderCode} · ${order.customerName}', style: text.titleMedium),
                      Text(
                        'Đặt lúc ${formatTime(order.createdAt)} · $count món'
                        '${order.pickupAt == null ? '' : ' · nhận ${formatTime(order.pickupAt!)}'}',
                        style: text.bodyMedium?.copyWith(color: colors.muted),
                      ),
                    ],
                  ),
                ),
                Text(formatVnd(order.totalVnd), style: text.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewQueueViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final busy = vm.approve.running || vm.reject.running;
    return SingleChildScrollView(
      child: AdminPanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Đơn ${order.orderCode}', style: text.headlineSmall)),
                const StatusBadge(label: 'Chờ duyệt', warning: true),
              ],
            ),
            Text(
              '${order.customerName} · ${paymentMethodLabel(order.paymentMethod)}',
              style: text.bodyMedium?.copyWith(color: colors.muted),
            ),
            const Divider(height: AppSpacing.xl),
            for (final line in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${line.quantity}×', style: text.titleMedium),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.name, style: text.bodyLarge),
                          if (line.note.isNotEmpty)
                            Text('Ghi chú: ${line.note}', style: text.bodyMedium?.copyWith(color: colors.muted)),
                        ],
                      ),
                    ),
                    Text(formatVnd(line.priceVnd * line.quantity), style: text.bodyLarge),
                  ],
                ),
              ),
            if (order.note.isNotEmpty) Text('Ghi chú đơn: ${order.note}', style: text.bodyMedium),
            const Divider(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(child: Text('Tổng cộng', style: text.titleMedium)),
                Text(formatVnd(order.totalVnd), style: text.headlineSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Thời gian làm xong', style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            _ReadyInPicker(key: ValueKey(order.id), busy: busy),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Từ chối đơn',
              icon: Icons.close,
              variant: AppButtonVariant.destructive,
              onPressed: busy ? null : () => _askReason(context, vm),
              loading: vm.reject.running,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _askReason(BuildContext context, ReviewQueueViewModel vm) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(order: order),
    );
    if (reason != null) await vm.reject.execute(reason);
  }
}

/// Picks how long the kitchen needs, then approves.
class _ReadyInPicker extends StatefulWidget {
  const _ReadyInPicker({super.key, required this.busy});

  final bool busy;

  @override
  State<_ReadyInPicker> createState() => _ReadyInPickerState();
}

class _ReadyInPickerState extends State<_ReadyInPicker> {
  int _minutes = ReviewQueueViewModel.readyInChoices.first;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ReviewQueueViewModel>();
    final choices = [...ReviewQueueViewModel.readyInChoices]..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final m in choices)
              AppChip(label: '$m phút', selected: m == _minutes, onSelected: (_) => setState(() => _minutes = m)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Duyệt đơn · xong sau $_minutes phút',
          icon: Icons.check,
          large: true,
          loading: vm.approve.running,
          onPressed: widget.busy ? null : () => vm.approve.execute(Duration(minutes: _minutes)),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.order});

  final Order order;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _other = TextEditingController();
  String? _picked = ReviewQueueViewModel.rejectReasons.first;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  String get _reason => (_picked ?? _other.text).trim();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Từ chối đơn ${widget.order.orderCode}?'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Khách sẽ thấy lý do này trên ứng dụng.'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final r in ReviewQueueViewModel.rejectReasons)
                AppChip(label: r, selected: r == _picked, onSelected: (_) => setState(() => _picked = r)),
              AppChip(
                label: 'Lý do khác',
                selected: _picked == null,
                onSelected: (_) => setState(() => _picked = null),
              ),
            ],
          ),
          if (_picked == null) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Lý do', controller: _other, onChanged: (_) => setState(() {})),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
      FilledButton(
        onPressed: _reason.isEmpty ? null : () => Navigator.pop(context, _reason),
        child: const Text('Từ chối đơn'),
      ),
    ],
  );
}
