import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/cart/view_models/cart_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _clear(BuildContext context, CartViewModel vm) async {
    final confirmed = await showAppDialog(
      context,
      title: 'Xoá hết giỏ hàng?',
      message: 'Mọi món trong giỏ sẽ bị xoá. Bạn có thể chọn lại từ thực đơn.',
      confirmLabel: 'Xoá hết',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final result = await vm.clearCart.execute();
    if (context.mounted) showResultError(context, result);
  }

  Future<void> _change(BuildContext context, CartViewModel vm, String itemId, int delta) async {
    final result = await vm.changeQuantity(itemId, delta);
    if (context.mounted) showResultError(context, result);
  }

  Future<void> _editNote(BuildContext context, CartViewModel vm, CartItem item) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _NoteSheet(item: item),
    );
    if (note == null || !context.mounted) return;
    final result = await vm.setNote(item.itemId, note);
    if (context.mounted) showResultError(context, result);
  }

  Future<void> _removeVoucher(BuildContext context, CartViewModel vm) async {
    final result = await vm.removeVoucher.execute();
    if (context.mounted) showResultError(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CartViewModel>();
    final hasItems = vm.state is ViewData<List<CartItem>>;
    return Scaffold(
      appBar: AppTopBar(
        title: 'Giỏ hàng',
        onBack: () => context.pop(),
        actions: [
          if (hasItems)
            TestId(
              's05.clear',
              child: AppIconButton(
                icon: Icons.delete_outline,
                semanticLabel: 'Xoá hết giỏ hàng',
                onPressed: () => _clear(context, vm),
              ),
            ),
        ],
      ),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải giỏ hàng…'),
        ViewError(:final message) => TestId(
          's05.retry',
          child: ErrorView(message: message, onRetry: vm.retry),
        ),
        ViewEmpty(:final message) => TestId(
          's05.empty',
          child: EmptyView(
            message: message ?? 'Giỏ hàng đang trống.',
            icon: Icons.shopping_cart_outlined,
            actionLabel: 'Xem thực đơn',
            onAction: () => context.go(AppRoutes.menu),
          ),
        ),
        ViewData(:final data) => Column(
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
                  _PickupCard(vm: vm),
                  for (final item in data) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _CartLine(
                      item: item,
                      imageUrl: vm.imageUrlOf(item.itemId),
                      onIncrement: item.quantity < Cart.maxQuantity ? () => _change(context, vm, item.itemId, 1) : null,
                      onDecrement: () => _change(context, vm, item.itemId, -1),
                      onEditNote: () => _editNote(context, vm, item),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _VoucherRow(vm: vm, onRemove: () => _removeVoucher(context, vm)),
                  const SizedBox(height: AppSpacing.sm),
                  _Summary(vm: vm),
                  if (vm.blocker case final message?) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _Blocker(message: message),
                  ],
                ],
              ),
            ),
            BottomActionButton(
              label: 'Tiếp tục thanh toán',
              testId: 's05.checkout',
              onPressed: vm.canCheckout ? () => context.push(AppRoutes.checkout) : null,
            ),
          ],
        ),
      },
    );
  }
}

class _PickupCard extends StatelessWidget {
  const _PickupCard({required this.vm});

  final CartViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final when = vm.pickupChosen
        ? 'Hẹn nhận lúc ${formatTime(vm.readyAt)}'
        : 'Dự kiến sẵn sàng ${formatTime(vm.readyAt)}';
    return TestId(
      's05.pickup',
      child: ProfileSection(
        child: ListTile(
          minTileHeight: AppA11y.minTouchTarget + AppSpacing.md,
          leading: Icon(Icons.location_on, color: colors.primaryText),
          title: Text(
            'Nhận tại ${vm.kiosk?.name ?? 'kiosk'}',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Row(
            children: [
              Icon(Icons.schedule, size: 16, color: colors.muted),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(when, style: text.bodyMedium?.copyWith(color: colors.muted)),
              ),
            ],
          ),
          trailing: Icon(Icons.chevron_right, color: colors.muted),
          onTap: () => context.push(AppRoutes.cartPickupTime),
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.imageUrl,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditNote,
  });

  final CartItem item;
  final String? imageUrl;
  final VoidCallback? onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final testId = 's05.item.${item.itemId}';
    return TestId(
      testId,
      child: ProfileSection(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MenuItemImage(imageUrl: imageUrl, size: 64),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                              style: text.bodyMedium?.copyWith(
                                color: item.note.isEmpty ? colors.primaryText : colors.muted,
                              ),
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
                          onIncrement: onIncrement,
                          onDecrement: onDecrement,
                          testId: testId,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoucherRow extends StatelessWidget {
  const _VoucherRow({required this.vm, required this.onRemove});

  final CartViewModel vm;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final code = vm.quote.value.voucherCode;
    final problem = vm.voucherProblem;
    final Widget title;
    final Widget? trailing;
    if (code == null) {
      title = Text('Chọn mã giảm giá', style: text.bodyLarge);
      trailing = Icon(Icons.chevron_right, color: colors.muted);
    } else if (problem != null) {
      title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(code, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(problem, style: text.bodyMedium?.copyWith(color: scheme.error)),
        ],
      );
      trailing = TestId(
        's05.voucher.remove',
        child: TextButton(onPressed: onRemove, child: const Text('Bỏ mã')),
      );
    } else {
      title = Text(
        '$code · −${formatVnd(vm.pricing.discountVnd)}',
        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      );
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 18, color: colors.success),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'Đã áp dụng',
            style: text.bodyMedium?.copyWith(color: colors.success, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }
    return TestId(
      's05.voucher',
      child: ProfileSection(
        child: ListTile(
          minTileHeight: AppA11y.minTouchTarget + AppSpacing.xs,
          leading: Icon(Icons.local_offer, color: problem == null ? colors.primaryText : scheme.error),
          title: title,
          trailing: trailing,
          onTap: () => context.push(AppRoutes.cartVouchers),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.vm});

  final CartViewModel vm;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final pricing = vm.pricing;
    Widget row(String label, String value, {bool strong = false}) => Padding(
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
                : text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return TestId(
      's05.summary',
      child: ProfileSection(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              row('Tạm tính (${vm.itemCount} món)', formatVnd(pricing.subtotalVnd)),
              if (pricing.discountVnd > 0) row(vm.voucher?.title ?? 'Ưu đãi', '−${formatVnd(pricing.discountVnd)}'),
              row('Phí kiosk', formatVnd(0)),
              Divider(height: AppSpacing.md, color: colors.border),
              row('Tổng thanh toán', formatVnd(pricing.totalVnd), strong: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _Blocker extends StatelessWidget {
  const _Blocker({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: scheme.error),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: text.bodyMedium?.copyWith(color: scheme.error)),
            ),
          ],
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
            's05.noteField',
            child: TextField(
              controller: _controller,
              autofocus: true,
              maxLength: CartViewModel.maxNoteLength,
              decoration: const InputDecoration(hintText: 'Ví dụ: ít cay, không hành'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: TestId(
              's05.noteSave',
              child: AppButton(label: 'Lưu ghi chú', onPressed: () => Navigator.of(context).pop(_controller.text)),
            ),
          ),
        ],
      ),
    );
  }
}
