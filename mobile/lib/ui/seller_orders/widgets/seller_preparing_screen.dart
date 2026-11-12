import 'dart:async';

import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_order_actions.dart';
import 'package:breakbite/ui/seller_orders/view_models/seller_order_view_model.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_order_parts.dart';
import 'package:breakbite/ui/seller_orders/widgets/seller_order_screen.dart';
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

/// K04: the order being made. A countdown to the time it is wanted, a check list of the dishes, "Xong, báo
/// sẵn sàng" and, when an ingredient runs out, the way to turn the order down (K12).
class SellerPreparingScreen extends StatelessWidget {
  const SellerPreparingScreen({super.key});

  Future<void> _ready(BuildContext context, SellerOrderViewModel vm) async {
    final result = await vm.markReady();
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        showAppMessage(context, 'Đã báo khách: món sẵn sàng.');
        context.go(AppRoutes.sellerOrders);
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellerOrderViewModel>();
    final order = vm.order;
    return Scaffold(
      appBar: AppTopBar(
        title: order == null ? 'Đang làm' : 'Đang làm #${order.orderCode.isEmpty ? order.id : order.orderCode}',
        onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.sellerOrders),
      ),
      bottomNavigationBar: order != null && order.status == OrderStatus.preparing
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.xs,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TestId(
                      'k04.ready',
                      child: AppButton(
                        label: 'Xong, báo sẵn sàng',
                        loading: vm.busy,
                        onPressed: () => _ready(context, vm),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TestId(
                      'k04.shortage',
                      child: AppButton(
                        label: 'Báo thiếu nguyên liệu',
                        variant: AppButtonVariant.text,
                        onPressed: vm.busy ? null : () => rejectFlow(context, vm),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : order != null && order.status == OrderStatus.ready
          ? BottomActionButton(
              label: 'Giao món',
              testId: 'k04.toDeliver',
              onPressed: () => context.pushReplacement(AppRoutes.sellerOrderDeliverOf(order.id)),
            )
          : null,
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải đơn…'),
        ViewError(:final message) => TestId(
          'k04.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          'k04.empty',
          child: EmptyView(message: message ?? SellerOrderViewModel.notFoundMessage, icon: Icons.receipt_long_outlined),
        ),
        ViewData(:final data) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                if (data.status == OrderStatus.preparing)
                  _Countdown(order: data, now: () => vm.now)
                else
                  TestId(
                    'k04.state',
                    child: SellerCard(
                      child: Text(
                        data.status == OrderStatus.ready
                            ? 'Món đã sẵn sàng, chờ khách tới nhận.'
                            : 'Đơn này ${orderStatusLabel(data.status).toLowerCase()}, không còn ở bước làm món.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                OrderLinesCard(
                  order: data,
                  idPrefix: 'k04',
                  checked: data.status == OrderStatus.preparing ? vm.isChecked : null,
                  onToggle: data.status == OrderStatus.preparing ? vm.toggle : null,
                ),
                OrderNoteCard(order: data),
              ],
            ),
          ),
        ),
      },
    );
  }
}

/// "Còn 02:35" and a bar that fills up as the time to [Order.readyBy] runs out. Ticks every second.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.order, required this.now});

  final Order order;
  final DateTime Function() now;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final by = widget.order.readyBy;
    final started = widget.order.acceptedAt;
    final left = by?.difference(widget.now());
    final late = left != null && left.isNegative;
    double? progress;
    if (by != null && started != null) {
      final total = by.difference(started).inSeconds;
      if (total > 0) progress = (widget.now().difference(started).inSeconds / total).clamp(0.0, 1.0);
    }
    return TestId(
      'k04.countdown',
      child: SellerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              countdownLabel(left),
              style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: late ? scheme.error : null),
            ),
            if (by != null)
              Text('Hạn sẵn sàng ${formatTime(by)}', style: text.bodyMedium?.copyWith(color: colors.muted)),
            if (progress != null) ...[
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: late ? scheme.error : scheme.primary,
                  backgroundColor: colors.surfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
