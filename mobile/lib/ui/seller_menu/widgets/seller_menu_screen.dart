import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/ui/seller_menu/view_models/seller_menu_view_model.dart';
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

/// K08: the menu of the staff member's kiosk with a switch per item; K09 is the sheet that opens when an
/// item is switched off.
class SellerMenuScreen extends StatelessWidget {
  const SellerMenuScreen({super.key});

  Future<void> _toggle(BuildContext context, SellerMenuViewModel vm, MenuItem item, {required bool onSale}) async {
    if (onSale) {
      final result = await vm.markAvailable(item);
      if (!context.mounted) return;
      switch (result) {
        case Ok():
          showAppMessage(context, '${item.name} đã bán lại.');
        case Err(:final error):
          showAppMessage(context, error.message);
      }
      return;
    }
    final choice = await showModalBottomSheet<SoldOutChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SoldOutSheet(item: item, backOptions: vm.backOptions),
    );
    if (choice == null || !context.mounted) return;
    final result = await vm.markSoldOut(item, reason: choice.reason, backAt: choice.backAt);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        showAppMessage(context, '${item.name} đã chuyển sang hết hàng.');
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellerMenuViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: 'Món tại quầy',
        actions: [
          if (vm.canAdd)
            TestId(
              'k08.add',
              child: AppIconButton(
                icon: Icons.add,
                semanticLabel: 'Thêm món',
                onPressed: () => context.push(AppRoutes.sellerMenuNew),
              ),
            ),
        ],
      ),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải thực đơn…'),
        ViewError(:final message) => TestId(
          'k08.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'k08.empty',
          child: EmptyView(
            message: message ?? SellerMenuViewModel.emptyMessage,
            icon: Icons.restaurant_menu,
            actionLabel: vm.hasKiosk ? 'Thêm món đầu tiên' : null,
            onAction: vm.hasKiosk ? () => context.push(AppRoutes.sellerMenuNew) : null,
          ),
        ),
        ViewData() => _Body(
          vm: vm,
          onToggle: (item, {required onSale}) => _toggle(context, vm, item, onSale: onSale),
        ),
      },
    );
  }
}

typedef _Toggle = Future<void> Function(MenuItem item, {required bool onSale});

class _Body extends StatelessWidget {
  const _Body({required this.vm, required this.onToggle});

  final SellerMenuViewModel vm;
  final _Toggle onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final emptyFilter = vm.emptyFilterMessage;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.xl * 3,
          ),
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                TestId(
                  'k08.filter.all',
                  child: AppChip(
                    label: 'Tất cả',
                    selected: vm.filter == SellerMenuFilter.all,
                    onSelected: (_) => vm.setFilter(SellerMenuFilter.all),
                  ),
                ),
                TestId(
                  'k08.filter.available',
                  child: AppChip(
                    label: 'Đang bán',
                    selected: vm.filter == SellerMenuFilter.available,
                    onSelected: (_) => vm.setFilter(SellerMenuFilter.available),
                  ),
                ),
                TestId(
                  'k08.filter.soldOut',
                  child: AppChip(
                    label: 'Hết',
                    selected: vm.filter == SellerMenuFilter.soldOut,
                    onSelected: (_) => vm.setFilter(SellerMenuFilter.soldOut),
                  ),
                ),
              ],
            ),
            if (emptyFilter != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: TestId(
                  'k08.emptyFilter',
                  child: Text(emptyFilter, textAlign: TextAlign.center, style: text.bodyLarge),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in vm.groups.expand((g) => g.items))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _ItemRow(vm: vm, item: item, onToggle: onToggle),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.vm, required this.item, required this.onToggle});

  final SellerMenuViewModel vm;
  final MenuItem item;
  final _Toggle onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final id = 'k08.item.${item.id}';
    return TestId(
      id,
      child: ProfileSection(
        child: Row(
          children: [
            // The text opens the item in K15; the switch is separate so it never opens it by mistake.
            Expanded(
              child: TestId(
                '$id.edit',
                child: Semantics(
                  button: true,
                  label: 'Sửa ${item.name}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.sellerMenuEditOf(item.id)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, 0, AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Text(
                            '${formatVnd(item.priceVnd)} · ${vm.statusLine(item)}',
                            style: text.bodyMedium?.copyWith(
                              color: item.soldOut ? scheme.error : colors.muted,
                              fontWeight: item.soldOut ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            TestId(
              '$id.switch',
              child: Semantics(
                label: item.soldOut ? 'Bán lại ${item.name}' : 'Báo hết ${item.name}',
                toggled: !item.soldOut,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Switch(
                    value: !item.soldOut,
                    onChanged: vm.isBusy(item.id) ? null : (onSale) => onToggle(item, onSale: onSale),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What staff picked in K09.
class SoldOutChoice {
  const SoldOutChoice({required this.reason, this.backAt});

  final SoldOutReason reason;

  /// When the item is expected back; `null` for "Hết ngày".
  final DateTime? backAt;
}

class _SoldOutSheet extends StatefulWidget {
  const _SoldOutSheet({required this.item, required this.backOptions});

  final MenuItem item;
  final List<DateTime> backOptions;

  @override
  State<_SoldOutSheet> createState() => _SoldOutSheetState();
}

class _SoldOutSheetState extends State<_SoldOutSheet> {
  var _reason = SoldOutReason.outOfIngredients;
  late DateTime? _backAt = widget.backOptions.first;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return SafeArea(
      child: SingleChildScrollView(
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
            Text('Đánh dấu hết món', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xxs),
            Text(widget.item.name, style: text.bodyMedium?.copyWith(color: colors.muted)),
            const SizedBox(height: AppSpacing.sm),
            Text('Lý do', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final reason in SoldOutReason.values)
                  TestId(
                    'k09.reason.${reason.name}',
                    child: AppChip(
                      label: soldOutReasonLabel(reason),
                      selected: _reason == reason,
                      onSelected: (_) => setState(() => _reason = reason),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Có lại lúc', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final back in widget.backOptions)
                  TestId(
                    'k09.back.${formatTime(back).replaceAll(':', '')}',
                    child: AppChip(
                      label: formatTime(back),
                      selected: _backAt == back,
                      onSelected: (_) => setState(() => _backAt = back),
                    ),
                  ),
                TestId(
                  'k09.back.endOfDay',
                  child: AppChip(
                    label: 'Hết ngày',
                    selected: _backAt == null,
                    onSelected: (_) => setState(() => _backAt = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: TestId(
                'k09.confirm',
                child: AppButton(
                  label: 'Xác nhận hết món',
                  large: true,
                  onPressed: () => Navigator.of(context).pop(SoldOutChoice(reason: _reason, backAt: _backAt)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: TestId(
                'k09.cancel',
                child: AppButton(
                  label: 'Huỷ',
                  variant: AppButtonVariant.text,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
