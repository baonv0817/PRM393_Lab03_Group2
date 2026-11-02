import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/ui/seller_shop/view_models/shop_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// K10: the staff member's kiosk. Whether it takes orders, a pause and the wait apply as soon as they are
/// tapped; the notice, hours and slot capacity are saved with the button at the bottom.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  Future<void> _run(BuildContext context, Future<Result<void>> action, String? done) async {
    final result = await action;
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        if (done != null) showAppMessage(context, done);
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  Future<void> _saveInfo(BuildContext context, ShopViewModel vm) async {
    final result = await vm.saveInfo.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        showAppMessage(context, 'Đã lưu thông tin quán.');
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShopViewModel>();
    // This screen is a tab of the seller shell, whose Scaffold would show a message below this screen's
    // own bottom bar and cover the save button. Its own messenger makes this Scaffold show them instead,
    // above its bottom bar.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          appBar: const AppTopBar(title: 'Quán'),
          // In the bottom bar, not in the body: a message from the Scaffold then appears above the button
          // instead of covering it.
          bottomNavigationBar: vm.state is ViewData<Kiosk> && vm.infoDirty
              ? ListenableBuilder(
                  listenable: vm.saveInfo,
                  builder: (context, _) => BottomActionButton(
                    label: 'Lưu thông tin',
                    testId: 'k10.save',
                    loading: vm.saveInfo.running,
                    onPressed: vm.saveInfo.running ? null : () => _saveInfo(context, vm),
                  ),
                )
              : null,
          body: switch (vm.state) {
            ViewLoading() => const LoadingView(message: 'Đang tải thông tin quán…'),
            ViewError(:final message) => TestId(
              'k10.retry',
              child: ErrorView(message: message, onRetry: vm.load),
            ),
            ViewEmpty(:final message) => TestId(
              'k10.empty',
              child: EmptyView(message: message ?? ShopViewModel.noKioskMessage, icon: Icons.storefront_outlined),
            ),
            ViewData() => _Body(vm: vm, onApply: (action, done) => _run(context, action, done)),
          },
        ),
      ),
    );
  }
}

/// Runs a write and shows [done] when it worked (nothing when `null`, for taps that repeat) or the error.
typedef _Apply = Future<void> Function(Future<Result<void>> action, String? done);

class _Body extends StatefulWidget {
  const _Body({required this.vm, required this.onApply});

  final ShopViewModel vm;
  final _Apply onApply;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final _notice = TextEditingController(text: widget.vm.notice);
  late final _openTime = TextEditingController(text: widget.vm.openTime);
  late final _closeTime = TextEditingController(text: widget.vm.closeTime);
  late final _maxOrders = TextEditingController(text: widget.vm.maxOrders);

  @override
  void dispose() {
    _notice.dispose();
    _openTime.dispose();
    _closeTime.dispose();
    _maxOrders.dispose();
    super.dispose();
  }

  static String _pauseLabel(Duration d) => d.inMinutes < 60 ? '${d.inMinutes} phút' : '${d.inHours} giờ';

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final kiosk = vm.kiosk!;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final showErrors = vm.showErrors;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.md,
          ),
          children: [
            TestId(
              'k10.status',
              child: Material(
                color: scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: BorderSide(
                    color: vm.acceptsOrders ? colors.success : colors.border,
                    width: vm.acceptsOrders ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Đang nhận đơn', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                          TestId(
                            'k10.open',
                            child: Semantics(
                              label: kiosk.open ? 'Đóng quán' : 'Mở quán',
                              toggled: kiosk.open,
                              child: Switch(
                                value: kiosk.open,
                                onChanged: vm.applying
                                    ? null
                                    : (open) => widget.onApply(
                                        vm.setOpen(open),
                                        open ? 'Quán đã mở nhận đơn.' : 'Quán đã đóng, khách không đặt được nữa.',
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(kiosk.name, style: text.bodyMedium?.copyWith(color: colors.muted)),
                      Text(
                        vm.statusLine,
                        style: text.bodyMedium?.copyWith(
                          color: vm.acceptsOrders ? colors.success : scheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Tắt để khách thấy "Quán đóng"', style: text.bodyMedium?.copyWith(color: colors.muted)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TestId(
              'k10.pause.15',
              child: AppButton(
                label: 'Tạm ngưng nhận đơn ${_pauseLabel(ShopViewModel.pauseChoices.first)}',
                variant: AppButtonVariant.secondary,
                large: true,
                onPressed: vm.applying
                    ? null
                    : () => widget.onApply(
                        vm.pauseFor(ShopViewModel.pauseChoices.first),
                        'Tạm ngưng nhận đơn ${_pauseLabel(ShopViewModel.pauseChoices.first)}.',
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Tạm ngưng lâu hơn:', style: text.bodyMedium?.copyWith(color: colors.muted)),
                for (final d in ShopViewModel.pauseChoices.skip(1))
                  TestId(
                    'k10.pause.${d.inMinutes}',
                    child: AppChip(
                      label: _pauseLabel(d),
                      selected: false,
                      onSelected: vm.applying
                          ? (_) {}
                          : (_) => widget.onApply(vm.pauseFor(d), 'Tạm ngưng nhận đơn ${_pauseLabel(d)}.'),
                    ),
                  ),
              ],
            ),
            if (vm.isPaused) ...[
              const SizedBox(height: AppSpacing.xs),
              TestId(
                'k10.resume',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: 'Nhận đơn lại ngay',
                    icon: Icons.play_arrow,
                    variant: AppButtonVariant.secondary,
                    onPressed: vm.applying ? null : () => widget.onApply(vm.resume(), 'Quán nhận đơn lại.'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TestId(
              'k10.stats',
              child: ProfileSection(
                child: ListTile(
                  title: Text('Thống kê ca hôm nay', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.sellerStats),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Heading('Thời gian chờ', text),
            const SizedBox(height: AppSpacing.xxs),
            Text('Khách thấy thời gian này khi chọn kiosk.', style: text.bodyMedium?.copyWith(color: colors.muted)),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                QuantityStepper(
                  name: 'thời gian chờ',
                  quantity: vm.waitMinutes,
                  testId: 'k10.wait',
                  removesAtOne: false,
                  onDecrement: vm.canLowerWait && !vm.applying ? () => widget.onApply(vm.changeWait(-1), null) : null,
                  onIncrement: vm.canRaiseWait && !vm.applying ? () => widget.onApply(vm.changeWait(1), null) : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('phút', style: text.bodyLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Heading('Thông tin quán', text),
            const SizedBox(height: AppSpacing.sm),
            TestId(
              'k10.notice',
              child: TextField(
                controller: _notice,
                onChanged: vm.setNotice,
                minLines: 2,
                maxLines: 3,
                maxLength: KioskSettings.maxNoticeLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Thông báo cho khách (không bắt buộc)',
                  hintText: 'Ví dụ: Hôm nay hết sốt phô mai',
                  alignLabelWithHint: true,
                  errorText: showErrors ? vm.noticeError : null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TestId(
                    'k10.openTime',
                    child: TextField(
                      controller: _openTime,
                      onChanged: vm.setOpenTime,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Giờ mở cửa',
                        hintText: '06:30',
                        errorText: showErrors ? vm.openTimeError : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TestId(
                    'k10.closeTime',
                    child: TextField(
                      controller: _closeTime,
                      onChanged: vm.setCloseTime,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Giờ đóng cửa',
                        hintText: '17:00',
                        errorText: showErrors ? vm.closeTimeError : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TestId(
              'k10.maxOrders',
              child: TextField(
                controller: _maxOrders,
                onChanged: vm.setMaxOrders,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                decoration: InputDecoration(
                  labelText: 'Số đơn tối đa mỗi khung giờ nhận món',
                  helperText: 'Để trống nếu không giới hạn.',
                  errorText: showErrors ? vm.maxOrdersError : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label, this.text);

  final String label;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(label, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
  );
}
