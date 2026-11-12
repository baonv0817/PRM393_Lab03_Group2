import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/notifications/view_models/notification_center_view_model.dart';
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

/// S19: the notifications of the customer, "Hôm nay" and "Trước đó". A card opens the order it is about; an
/// "order is ready" card also has "Xem mã nhận món", which opens the pickup code (S20).
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  Future<void> _open(BuildContext context, NotificationCenterViewModel vm, AppNotification n, String route) async {
    final result = await vm.open(n);
    if (!context.mounted) return;
    if (result case Err(:final error)) showAppMessage(context, error.message);
    await context.push(route);
  }

  Future<void> _readAll(BuildContext context, NotificationCenterViewModel vm) async {
    final result = await vm.markAllRead();
    if (!context.mounted) return;
    showResultError(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationCenterViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: 'Thông báo',
        onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
        actions: [
          if (vm.unreadCount > 0)
            TestId(
              's19.readAll',
              child: AppIconButton(
                icon: Icons.done_all,
                semanticLabel: 'Đánh dấu đã đọc hết',
                onPressed: () => _readAll(context, vm),
              ),
            ),
        ],
      ),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải thông báo…'),
        ViewError(:final message) => TestId(
          's19.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty(:final message) => TestId(
          's19.empty',
          child: EmptyView(
            message: message ?? NotificationCenterViewModel.emptyMessage,
            icon: Icons.notifications_none,
            actionLabel: 'Về trang chủ',
            onAction: () => context.go(AppRoutes.home),
          ),
        ),
        ViewData() => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                if (vm.today.isNotEmpty) ...[
                  const _Header('Hôm nay'),
                  for (final n in vm.today) _Card(vm: vm, notification: n, onOpen: _open),
                ],
                if (vm.earlier.isNotEmpty) ...[
                  const _Header('Trước đó'),
                  for (final n in vm.earlier) _Card(vm: vm, notification: n, onOpen: _open),
                ],
              ],
            ),
          ),
        ),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    ),
  );
}

typedef _Open = Future<void> Function(BuildContext, NotificationCenterViewModel, AppNotification, String);

/// A notification id like `A-204_ready` as the part of a test id (an underscore is not allowed there).
String _key(AppNotification n) => n.id.replaceAll('_', '-');

class _Card extends StatelessWidget {
  const _Card({required this.vm, required this.notification, required this.onOpen});

  final NotificationCenterViewModel vm;
  final AppNotification notification;
  final _Open onOpen;

  String get _time {
    final local = notification.receivedAt.toLocal();
    final now = vm.today.contains(notification) ? formatTime(local) : formatDayMonth(local);
    return notification.read ? '$now · Đã xem' : now;
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final orderId = n.orderId;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: TestId(
        's19.item.${_key(n)}',
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: n.read ? colors.border : scheme.primary, width: n.read ? 1 : 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: orderId == null ? () => vm.open(n) : () => onOpen(context, vm, n, AppRoutes.orderOf(orderId)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!n.read)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: AppSpacing.xs),
                          child: Semantics(
                            label: 'Chưa đọc',
                            child: Icon(Icons.circle, size: 10, color: scheme.primary),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          n.title,
                          style: text.titleMedium?.copyWith(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  if (n.body.isNotEmpty) Text(n.body, style: text.bodyMedium?.copyWith(color: colors.muted)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(_time, style: text.bodyMedium?.copyWith(color: colors.muted)),
                  if (NotificationCenterViewModel.isReady(n) && orderId != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TestId(
                      's19.code.${_key(n)}',
                      child: AppButton(
                        label: 'Xem mã nhận món',
                        variant: AppButtonVariant.secondary,
                        large: true,
                        onPressed: () => onOpen(context, vm, n, AppRoutes.orderPickupOf(orderId)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
