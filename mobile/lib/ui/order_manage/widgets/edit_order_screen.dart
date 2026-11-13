import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/order_manage/view_models/edit_order_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
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

/// S09: change quantities, notes and the voucher of an order the kitchen has not taken yet.
class EditOrderScreen extends StatelessWidget {
  const EditOrderScreen({super.key});

  void _back(BuildContext context, EditOrderViewModel vm) =>
      context.canPop() ? context.pop() : context.go(AppRoutes.orderOf(vm.orderId));

  Future<void> _save(BuildContext context, EditOrderViewModel vm) async {
    final result = await vm.save.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        showAppMessage(context, 'Đã cập nhật đơn.');
        _back(context, vm);
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  Future<void> _editNote(BuildContext context, EditOrderViewModel vm, CartItem item) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _NoteSheet(item: item),
    );
    if (note != null) vm.setNote(item.lineKey, note);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditOrderViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Sửa đơn', onBack: () => _back(context, vm)),
      // In the bottom bar, not in the body: a message from the Scaffold then appears above the button
      // instead of covering it.
      bottomNavigationBar: vm.state is ViewData<Order> && !vm.locked
          ? ListenableBuilder(
              listenable: vm.save,
              builder: (context, _) => BottomActionButton(
                label: 'Lưu thay đổi',
                testId: 's09.save',
                loading: vm.save.running,
                onPressed: vm.canSave && !vm.save.running ? () => _save(context, vm) : null,
              ),
            )
          : null,
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn hàng…'),
        ViewError(:final message) => TestId(
          's09.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          's09.empty',
          child: EmptyView(
            message: message ?? EditOrderViewModel.notFoundMessage,
            actionLabel: 'Xem đơn hàng',
            onAction: () => context.go(AppRoutes.orders),
          ),
        ),
        ViewData(:final data) when vm.locked => TestId(
          's09.locked',
          child: EmptyView(
            message: EditOrderViewModel.lockedMessage,
            icon: Icons.lock_outline,
            actionLabel: 'Xem đơn',
            onAction: () => context.go(AppRoutes.orderOf(data.id)),
          ),
        ),
        ViewData(:final data) => _Body(vm: vm, order: data, onEditNote: (item) => _editNote(context, vm, item)),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm, required this.order, required this.onEditNote});

  final EditOrderViewModel vm;
  final Order order;
  final ValueChanged<CartItem> onEditNote;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final items = vm.items;
    final onlyOne = items.length == 1 && items.single.quantity == 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.md,
      ),
      children: [
        TestId(
          's09.header',
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
                  Text(
                    'Sửa được đến khi bếp nhận đơn. Số tiền được tính lại khi bạn lưu.',
                    style: text.bodyMedium?.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final item in items) ...[
          const SizedBox(height: AppSpacing.sm),
          _EditLine(
            item: item,
            removesAtOne: items.length > 1,
            onIncrement: vm.canIncrease(item.lineKey) ? () => vm.changeQuantity(item.lineKey, 1) : null,
            onDecrement: vm.canDecrease(item.lineKey) ? () => vm.changeQuantity(item.lineKey, -1) : null,
            onEditNote: () => onEditNote(item),
          ),
        ],
        if (onlyOne)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: TestId(
              's09.lastLine',
              child: Text(EditOrderViewModel.lastLineMessage, style: text.bodyMedium?.copyWith(color: colors.muted)),
            ),
          ),
        if (vm.voucherCode != null) ...[const SizedBox(height: AppSpacing.sm), _VoucherRow(vm: vm)],
        const SizedBox(height: AppSpacing.sm),
        _Summary(vm: vm, order: order),
      ],
    );
  }
}

class _EditLine extends StatelessWidget {
  const _EditLine({
    required this.item,
    required this.removesAtOne,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditNote,
  });

  final CartItem item;
  final bool removesAtOne;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final testId = 's09.item.${item.lineSlug}';
    return TestId(
      testId,
      child: ProfileSection(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.options.isNotEmpty)
                Text(item.optionsSummary, style: text.bodyMedium?.copyWith(color: context.appColors.muted)),
              TestId(
                '$testId.note',
                child: InkWell(
                  onTap: onEditNote,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppA11y.minTouchTarget),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.note.isEmpty ? '+ Thêm ghi chú cho bếp' : item.note,
                        style: text.bodyMedium?.copyWith(color: item.note.isEmpty ? colors.primaryText : colors.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatVnd(item.lineTotalVnd),
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  QuantityStepper(
                    name: item.name,
                    quantity: item.quantity,
                    removesAtOne: removesAtOne,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement,
                    testId: testId,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoucherRow extends StatelessWidget {
  const _VoucherRow({required this.vm});

  final EditOrderViewModel vm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final code = vm.voucherCode!;
    final problem = vm.voucherProblem;
    final Widget title;
    final Widget action;
    if (vm.voucherDropped) {
      title = Text('Đã bỏ mã $code', style: text.bodyLarge?.copyWith(color: colors.muted));
      action = TestId(
        's09.voucher.keep',
        child: TextButton(onPressed: vm.keepVoucher, child: const Text('Dùng lại mã')),
      );
    } else {
      title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            problem == null ? '$code · −${formatVnd(vm.pricing.discountVnd)}' : code,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (problem != null) Text(problem, style: text.bodyMedium?.copyWith(color: scheme.error)),
        ],
      );
      action = TestId(
        's09.voucher.drop',
        child: TextButton(onPressed: vm.dropVoucher, child: const Text('Bỏ mã')),
      );
    }
    return TestId(
      's09.voucher',
      child: ProfileSection(
        child: ListTile(
          minTileHeight: AppA11y.minTouchTarget + AppSpacing.xs,
          leading: Icon(Icons.local_offer, color: problem == null ? colors.primaryText : scheme.error),
          title: title,
          trailing: action,
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.vm, required this.order});

  final EditOrderViewModel vm;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final pricing = vm.pricing;
    Widget row(String label, String value, {bool strong = false, bool muted = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong
                  ? text.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                  : text.bodyMedium?.copyWith(color: colors.muted),
            ),
          ),
          Text(
            value,
            style: strong
                ? text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)
                : text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: muted ? colors.muted : null),
          ),
        ],
      ),
    );
    return TestId(
      's09.summary',
      child: ProfileSection(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              row('Tạm tính (${vm.itemCount} món)', formatVnd(pricing.subtotalVnd)),
              if (pricing.discountVnd > 0) row('Mã ${vm.voucherCode}', '−${formatVnd(pricing.discountVnd)}'),
              Divider(height: AppSpacing.md, color: colors.border),
              TestId('s09.total', child: row('Tổng mới', formatVnd(pricing.totalVnd), strong: true)),
              if (vm.hasChanges) row('Trước khi sửa', formatVnd(order.totalVnd), muted: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.item});

  final CartItem item;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final _controller = TextEditingController(text: widget.item.note);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ghi chú cho ${widget.item.name}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          TestId(
            's09.noteField',
            child: TextField(
              controller: _controller,
              autofocus: true,
              maxLength: EditOrderViewModel.maxNoteLength,
              decoration: const InputDecoration(hintText: 'Ví dụ: ít cay, không hành'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: TestId(
              's09.noteSave',
              child: AppButton(label: 'Lưu ghi chú', onPressed: () => Navigator.of(context).pop(_controller.text)),
            ),
          ),
        ],
      ),
    );
  }
}
