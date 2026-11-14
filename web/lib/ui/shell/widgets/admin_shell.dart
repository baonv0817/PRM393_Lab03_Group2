import 'package:breakbite_admin/routing/router.dart';
import 'package:breakbite_admin/routing/system_pages.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/brand.dart';
import 'package:breakbite_core/ui/core/widgets/state_views.dart';
import 'package:breakbite_core/ui/core/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// The wide-screen frame of the Lab 2 handoff (section 3): the bottom bar becomes a Navigation Rail pinned on
/// the left, and the content sits on the cream page background.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool? _isExtended;

  static const _destinations = [
    (icon: Icons.inbox_outlined, selected: Icons.inbox_rounded, label: 'Duyệt đơn'),
    (icon: Icons.restaurant_menu_rounded, selected: Icons.restaurant_rounded, label: 'Thực đơn'),
    (icon: Icons.bar_chart_rounded, selected: Icons.analytics_rounded, label: 'Thống kê'),
    (icon: Icons.campaign_outlined, selected: Icons.campaign_rounded, label: 'Thông báo'),
  ];

  /// What only an admin sees, in the order of [SystemRoutes.tabs].
  static const _system = [
    (icon: Icons.people_outline_rounded, selected: Icons.people_rounded, label: 'Người dùng'),
    (icon: Icons.storefront_outlined, selected: Icons.storefront_rounded, label: 'Kiosk'),
    (icon: Icons.schedule_rounded, selected: Icons.access_time_filled_rounded, label: 'Khung giờ'),
    (icon: Icons.confirmation_number_outlined, selected: Icons.confirmation_number_rounded, label: 'Voucher'),
    (icon: Icons.receipt_long_outlined, selected: Icons.receipt_long_rounded, label: 'Mọi đơn hàng'),
    (icon: Icons.warning_amber_rounded, selected: Icons.warning_rounded, label: 'Sự cố'),
    (icon: Icons.trending_up_rounded, selected: Icons.insights_rounded, label: 'Thống kê hệ thống'),
    (icon: Icons.history_rounded, selected: Icons.history_toggle_off_rounded, label: 'Nhật ký'),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    final tabs = AdminRoutes.tabsFor(admin: session.isAdmin);
    final index = tabs.indexOf(widget.location);
    final colors = context.appColors;
    final autoExtended = MediaQuery.sizeOf(context).width >= 1200;
    final extended = _isExtended ?? autoExtended;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: index < 0 ? 0 : index,
            onDestinationSelected: (i) => context.go(tabs[i]),
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(label: 'BreakBite quản trị', child: BreakBiteLogo(size: extended ? 44 : 36)),
                  const SizedBox(height: AppSpacing.xs),
                  IconButton(
                    icon: Icon(
                      extended ? Icons.menu_open_rounded : Icons.menu_rounded,
                      size: 20,
                      color: colors.primaryText,
                    ),
                    tooltip: extended ? 'Thu gọn menu' : 'Mở rộng menu',
                    onPressed: () => setState(() => _isExtended = !extended),
                  ),
                ],
              ),
            ),
            destinations: [
              for (final d in [..._destinations, if (session.isAdmin) ..._system])
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                const _TopBar(),
                Expanded(
                  child: !session.online
                      ? Semantics(
                          liveRegion: true,
                          child: ErrorView(message: AdminSession.offlineMessage, onRetry: session.checkConnection),
                        )
                      : session.kioskId == null && !widget.location.startsWith(SystemRoutes.prefix)
                      ? _NoKiosk(session: session)
                      : widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// No kiosk to work on yet: still loading, the list failed, or there really is none (CR-F04).
class _NoKiosk extends StatelessWidget {
  const _NoKiosk({required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    if (session.kiosksError case final message?) {
      return ErrorView(message: message, onRetry: session.retryKiosks);
    }
    if (!session.kiosksLoaded) return const LoadingView(message: 'Đang tải danh sách kiosk…');
    return const EmptyView(message: 'Chưa có kiosk nào. Thêm kiosk trong Firestore rồi tải lại trang.');
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    final user = session.user;
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, color: colors.primaryText),
            const SizedBox(width: AppSpacing.xs),
            if (session.isAdmin && session.kiosks.isNotEmpty)
              Semantics(
                label: 'Chọn kiosk',
                child: PopupMenuButton<String>(
                  initialValue: session.kioskId,
                  tooltip: 'Chọn kiosk',
                  onSelected: session.selectKiosk,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    side: BorderSide(color: colors.border),
                  ),
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 4,
                  itemBuilder: (context) => [
                    for (final k in session.kiosks)
                      PopupMenuItem(
                        value: k.id,
                        child: Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: k.id == session.kioskId ? colors.primaryText : colors.muted,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                k.name,
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: k.id == session.kioskId ? FontWeight.w700 : FontWeight.w500,
                                  color: k.id == session.kioskId ? colors.primaryText : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (k.id == session.kioskId) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Icon(Icons.check_rounded, size: 16, color: colors.primaryText),
                            ],
                          ],
                        ),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_outlined, size: 18, color: colors.primaryText),
                        const SizedBox(width: AppSpacing.xs),
                        Text(session.kioskName, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: colors.muted),
                      ],
                    ),
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_outlined, color: colors.primaryText),
                  const SizedBox(width: AppSpacing.xs),
                  Text(session.kioskName, style: text.titleMedium),
                ],
              ),
            const Spacer(),
            if (user != null) ...[
              UserAvatar(name: user.displayName, photoUrl: user.photoUrl, size: 34),
              const SizedBox(width: AppSpacing.xs),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    session.isAdmin ? 'Quản trị viên' : 'Nhân viên kiosk',
                    style: text.bodySmall?.copyWith(color: colors.muted),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: session.signOut,
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Đăng xuất'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
