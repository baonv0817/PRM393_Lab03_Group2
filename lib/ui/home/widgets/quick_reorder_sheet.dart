import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/home/view_models/quick_reorder_view_model.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S14: opens the sheet of recent orders. Choosing "Thêm vào giỏ" fills the cart with that order and opens it.
Future<void> showQuickReorderSheet(BuildContext context) {
  final orders = context.read<OrderRepository>();
  final cart = context.read<CartRepository>();
  final analytics = context.read<AnalyticsService>();
  final crash = context.read<CrashService>();
  final uid = context.read<AuthViewModel>().user?.uid ?? '';
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => ChangeNotifierProvider(
      create: (_) => QuickReorderViewModel(orders: orders, cart: cart, analytics: analytics, crash: crash, uid: uid),
      child: QuickReorderSheet(
        onDone: () {
          Navigator.of(sheetContext).pop();
          router.push(AppRoutes.cart);
        },
        onMenu: () {
          Navigator.of(sheetContext).pop();
          router.go(AppRoutes.menu);
        },
      ),
    ),
  );
}

class QuickReorderSheet extends StatelessWidget {
  const QuickReorderSheet({super.key, required this.onDone, required this.onMenu});

  final VoidCallback onDone;
  final VoidCallback onMenu;

  Future<void> _add(BuildContext context, QuickReorderViewModel vm) async {
    final result = await vm.reorder.execute();
    if (!context.mounted || result == null) return;
    switch (result) {
      case Ok():
        onDone();
      case Err(:final error):
        showAppMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<QuickReorderViewModel>();
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          0,
          AppSpacing.screenPadding,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Đặt lại đơn gần đây', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: AppSpacing.sm),
            switch (vm.state) {
              ViewLoading() => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: LoadingView(message: 'Đang tải đơn…'),
              ),
              ViewError(:final message) => TestId(
                's14.retry',
                child: ErrorView(message: message, onRetry: vm.load),
              ),
              ViewEmpty(:final message) => TestId(
                's14.empty',
                child: EmptyView(
                  message: message ?? QuickReorderViewModel.emptyMessage,
                  icon: Icons.receipt_long_outlined,
                  actionLabel: 'Chọn từ thực đơn',
                  onAction: onMenu,
                ),
              ),
              ViewData(:final data) => Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final order in data)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: TestId(
                          's14.order.${order.id}',
                          child: SelectableCard(
                            selected: vm.chosen?.id == order.id,
                            onTap: () => vm.choose(order),
                            semanticLabel: '${_title(order)}. ${orderItemsSummary(order)}',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_title(order), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  order.items.map((e) => '${e.name} ×${e.quantity}').join(', '),
                                  style: text.bodyMedium?.copyWith(color: colors.muted),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  formatVnd(order.totalVnd),
                                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            },
            if (vm.state is ViewData<List<Order>>) ...[
              const SizedBox(height: AppSpacing.sm),
              ListenableBuilder(
                listenable: vm.reorder,
                builder: (context, _) => TestId(
                  's14.add',
                  child: AppButton(
                    label: 'Thêm vào giỏ · ${formatVnd(vm.chosenTotalVnd ?? 0)}',
                    loading: vm.reorder.running,
                    onPressed: () => _add(context, vm),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              TestId(
                's14.menu',
                child: AppButton(label: 'Chọn từ thực đơn', variant: AppButtonVariant.text, onPressed: onMenu),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _title(Order order) =>
      '#${order.orderCode.isEmpty ? order.id : order.orderCode} · ${formatDayMonth(order.createdAt)}';
}
