import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/cart/view_models/pickup_time_view_model.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class PickupTimeScreen extends StatelessWidget {
  const PickupTimeScreen({super.key});

  Future<void> _confirm(BuildContext context, PickupTimeViewModel vm) async {
    final result = await vm.confirm.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        context.pop();
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PickupTimeViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;

    final Widget body;
    if (!vm.enabled) {
      body = TestId(
        's25.disabled',
        child: EmptyView(
          message: 'Hẹn giờ nhận đang tạm tắt. Kiosk làm món ngay khi bạn đặt.',
          icon: Icons.schedule,
          actionLabel: 'Quay lại giỏ hàng',
          onAction: () => context.pop(),
        ),
      );
    } else {
      body = switch (vm.state) {
        ViewLoading<List<PickupDay>>() => const LoadingView(),
        ViewEmpty<List<PickupDay>>(:final message) => TestId(
          's25.empty',
          child: EmptyView(
            message: message ?? 'Giỏ hàng đang trống.',
            icon: Icons.shopping_cart_outlined,
            actionLabel: 'Quay lại',
            onAction: () => context.pop(),
          ),
        ),
        ViewError<List<PickupDay>>(:final message) => TestId(
          's25.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewData<List<PickupDay>>(:final data) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.md,
          ),
          children: [
            if (vm.kiosk case final kiosk?)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: colors.primaryText),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Nhận tại ${kiosk.name}',
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            SelectableCard(
              selected: vm.selectedId == null,
              onTap: vm.chooseAsap,
              semanticLabel: '${vm.asapLabel}. Kiosk làm món ngay khi nhận đơn',
              testId: 's25.asap',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vm.asapLabel, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('Kiosk làm món ngay khi nhận đơn', style: text.bodyMedium?.copyWith(color: colors.muted)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text('Hoặc hẹn theo giờ nghỉ', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (data.isEmpty)
              Text(PickupTimeViewModel.noSlotsMessage, style: text.bodyMedium?.copyWith(color: colors.muted))
            else
              for (final day in data) ...[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
                  child: Text(day.label, style: text.labelLarge?.copyWith(color: colors.muted)),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final slot in day.slots)
                      _SlotChip(
                        slot: slot,
                        note: vm.slotNote(slot),
                        selected: vm.selectedId == slot.id,
                        enabled: vm.problemOf(slot) == null,
                        onTap: () => vm.choose(slot),
                      ),
                  ],
                ),
              ],
            const SizedBox(height: AppSpacing.md),
            TestId(
              's25.summary',
              child: Semantics(
                liveRegion: true,
                child: Text(vm.summary, style: text.bodyMedium?.copyWith(color: colors.muted)),
              ),
            ),
          ],
        ),
      };
    }

    return Scaffold(
      appBar: AppTopBar(title: 'Hẹn giờ nhận', onBack: () => context.pop()),
      body: Column(
        children: [
          Expanded(child: body),
          if (vm.enabled)
            ListenableBuilder(
              listenable: vm.confirm,
              builder: (context, _) => BottomActionButton(
                label: 'Tiếp tục tới giỏ hàng',
                testId: 's25.confirm',
                loading: vm.confirm.running,
                onPressed: vm.canConfirm ? () => _confirm(context, vm) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.note,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PickupSlot slot;
  final String note;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final time = formatTime(slot.startAt);
    final background = !enabled
        ? colors.surfaceVariant
        : selected
        ? colors.selected
        : scheme.surface;
    return TestId(
      's25.slot.${slot.id}',
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: 'Nhận lúc $time${note.isEmpty ? '' : ', $note'}',
        excludeSemantics: true,
        child: Material(
          color: background,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? scheme.primary : colors.border, width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 80, minHeight: AppA11y.minTouchTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      time,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: enabled ? (selected ? colors.primaryText : null) : colors.muted,
                      ),
                    ),
                    if (note.isNotEmpty) Text(note, style: text.labelSmall?.copyWith(color: colors.muted)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
