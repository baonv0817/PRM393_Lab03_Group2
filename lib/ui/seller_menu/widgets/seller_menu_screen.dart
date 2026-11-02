import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/ui/seller_menu/view_models/seller_menu_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
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
      builder: (context) => _SoldOutSheet(item: item),
    );
    if (choice == null || !context.mounted) return;
    final result = await vm.markSoldOut(item, reason: choice.reason, backIn: choice.backIn);
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
      appBar: const AppTopBar(title: 'Quản lý món'),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải thực đơn…'),
        ViewError(:final message) => TestId(
          'k08.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'k08.empty',
          child: EmptyView(message: message ?? SellerMenuViewModel.emptyMessage, icon: Icons.restaurant_menu),
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
    final colors = context.appColors;
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
            AppSpacing.lg,
          ),
          children: [
            TestId(
              'k08.summary',
              child: ProfileSection(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.kioskName.isEmpty ? 'Kiosk của bạn' : vm.kioskName,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(vm.summary, style: text.bodyMedium?.copyWith(color: colors.muted)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                    label: 'Đang bán (${vm.availableCount})',
                    selected: vm.filter == SellerMenuFilter.available,
                    onSelected: (_) => vm.setFilter(SellerMenuFilter.available),
                  ),
                ),
                TestId(
                  'k08.filter.soldOut',
                  child: AppChip(
                    label: 'Hết hàng (${vm.soldOutCount})',
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
            for (final group in vm.groups) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
                child: Semantics(
                  header: true,
                  child: Text(group.label, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ),
              for (final item in group.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _ItemRow(vm: vm, item: item, onToggle: onToggle),
                ),
            ],
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
    final status = vm.statusLine(item);
    return TestId(
      id,
      child: ProfileSection(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(formatVnd(item.priceVnd), style: text.bodyMedium),
                    Text(
                      status,
                      style: text.bodyMedium?.copyWith(
                        color: item.soldOut ? scheme.error : colors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TestId(
                '$id.switch',
                child: Semantics(
                  label: item.soldOut ? 'Bán lại ${item.name}' : 'Báo hết ${item.name}',
                  toggled: !item.soldOut,
                  child: Switch(
                    value: !item.soldOut,
                    onChanged: vm.isBusy(item.id) ? null : (onSale) => onToggle(item, onSale: onSale),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What staff picked in K09.
class SoldOutChoice {
  const SoldOutChoice({required this.reason, this.backIn});

  final SoldOutReason reason;
  final Duration? backIn;
}

String _backLabel(Duration? backIn) => switch (backIn) {
  null => 'Chưa rõ',
  final d when d.inMinutes < 60 => 'Sau ${d.inMinutes} phút',
  final d => 'Sau ${d.inHours} giờ',
};

class _SoldOutSheet extends StatefulWidget {
  const _SoldOutSheet({required this.item});

  final MenuItem item;

  @override
  State<_SoldOutSheet> createState() => _SoldOutSheetState();
}

class _SoldOutSheetState extends State<_SoldOutSheet> {
  var _reason = SoldOutReason.outOfIngredients;
  Duration? _backIn;

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
            Text('Báo hết ${widget.item.name}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Khách sẽ thấy món này hết hàng ngay và không thêm vào giỏ được.',
              style: text.bodyMedium?.copyWith(color: colors.muted),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final reason in SoldOutReason.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: SelectableCard(
                  testId: 'k09.reason.${reason.name}',
                  selected: _reason == reason,
                  semanticLabel: soldOutReasonLabel(reason),
                  onTap: () => setState(() => _reason = reason),
                  child: Text(soldOutReasonLabel(reason), style: text.bodyLarge),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text('Dự kiến có lại', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final back in SellerMenuViewModel.backChoices)
                  TestId(
                    'k09.back.${back?.inMinutes ?? 'unknown'}',
                    child: AppChip(
                      label: _backLabel(back),
                      selected: _backIn == back,
                      onSelected: (_) => setState(() => _backIn = back),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: TestId(
                'k09.confirm',
                child: AppButton(
                  label: 'Báo hết hàng',
                  large: true,
                  onPressed: () => Navigator.of(context).pop(SoldOutChoice(reason: _reason, backIn: _backIn)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: TestId(
                'k09.cancel',
                child: AppButton(
                  label: 'Giữ nguyên',
                  variant: AppButtonVariant.secondary,
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
