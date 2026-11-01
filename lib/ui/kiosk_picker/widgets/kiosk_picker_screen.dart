import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/kiosk_picker/view_models/kiosk_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class KioskPickerScreen extends StatelessWidget {
  const KioskPickerScreen({super.key});

  Future<void> _confirm(BuildContext context, KioskViewModel vm) async {
    if (vm.choiceEmptiesCart) {
      final from = vm.cartKiosk?.name ?? 'kiosk khác';
      final agreed = await showAppDialog(
        context,
        title: 'Đổi sang ${vm.chosen?.name}?',
        message: 'Giỏ hàng đang có món của $from. Đổi kiosk sẽ làm trống giỏ hàng.',
        confirmLabel: 'Đổi kiosk',
        destructive: true,
      );
      if (agreed != true || !context.mounted) return;
    }
    final result = await vm.confirm.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok(:final value):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Đã chọn ${value.name}.')));
        if (context.canPop()) context.pop();
      case Err(:final error):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KioskViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Chọn Kiosk', onBack: () => context.pop()),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              AppSpacing.xs,
            ),
            child: TestId(
              's27.search',
              child: Semantics(
                textField: true,
                label: 'Tìm kiosk hoặc tầng',
                child: TextField(
                  onChanged: vm.search,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(hintText: 'Tìm kiosk hoặc tầng', prefixIcon: Icon(Icons.search)),
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (vm.kiosks) {
              ViewLoading() => const LoadingView(message: 'Đang tải danh sách kiosk…'),
              ViewEmpty(:final message) => EmptyView(message: message ?? 'Chưa có kiosk nào.', icon: Icons.storefront),
              ViewError(:final message) => TestId(
                's27.retry',
                child: ErrorView(message: message, onRetry: vm.load),
              ),
              ViewData(:final data) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.xs,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                itemCount: data.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) => _KioskCard(
                  kiosk: data[index],
                  selected: data[index].id == vm.chosenId,
                  now: vm.now,
                  onTap: () => vm.choose(data[index].id),
                ),
              ),
            },
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.xs,
                AppSpacing.screenPadding,
                AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ListenableBuilder(
                  listenable: vm.confirm,
                  builder: (context, _) => TestId(
                    's27.confirm',
                    child: AppButton(
                      label: 'Chọn kiosk này',
                      loading: vm.confirm.running,
                      onPressed: vm.canConfirm ? () => _confirm(context, vm) : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KioskCard extends StatelessWidget {
  const _KioskCard({required this.kiosk, required this.selected, required this.now, required this.onTap});

  final Kiosk kiosk;
  final bool selected;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final accepting = kiosk.acceptsOrders(now);
    final status = kioskStatusLabel(kiosk, now: now);
    final place = kiosk.location;
    final statusColor = accepting ? colors.success : scheme.error;

    return TestId(
      's27.kiosk.${kiosk.id}',
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: '${kiosk.name}. $status${place.isEmpty ? '' : '. $place'}',
        excludeSemantics: true,
        child: Material(
          color: selected ? colors.selected : scheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: selected ? scheme.primary : colors.border, width: selected ? 1.5 : 1),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, color: colors.primaryText),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kiosk.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                status,
                                style: accepting
                                    ? text.bodyMedium?.copyWith(color: colors.muted)
                                    : text.bodyMedium?.copyWith(color: scheme.error, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        if (place.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(place, style: text.bodyMedium?.copyWith(color: colors.muted)),
                        ],
                        if (!accepting && kiosk.notice != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(kiosk.notice!, style: text.bodyMedium?.copyWith(color: colors.muted)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: AppA11y.minTouchTarget,
                    height: AppA11y.minTouchTarget,
                    child: Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? scheme.primary : colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
