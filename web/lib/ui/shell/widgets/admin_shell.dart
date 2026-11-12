import 'package:breakbite_admin/routing/router.dart';
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
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _destinations = [
    (icon: Icons.fact_check_outlined, selected: Icons.fact_check, label: 'Duyệt đơn'),
    (icon: Icons.restaurant_menu_outlined, selected: Icons.restaurant_menu, label: 'Thực đơn'),
    (icon: Icons.insights_outlined, selected: Icons.insights, label: 'Thống kê'),
    (icon: Icons.campaign_outlined, selected: Icons.campaign, label: 'Thông báo'),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    final index = AdminRoutes.tabs.indexOf(location);
    final extended = MediaQuery.sizeOf(context).width >= 1200;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: index < 0 ? 0 : index,
            onDestinationSelected: (i) => context.go(AdminRoutes.tabs[i]),
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Semantics(label: 'BreakBite quản trị', child: const BreakBiteLogo(size: 48)),
            ),
            destinations: [
              for (final d in _destinations)
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
                      : session.kioskId == null
                      ? const EmptyView(message: 'Chưa có kiosk nào. Thêm kiosk trong Firestore rồi tải lại trang.')
                      : child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                child: DropdownButton<String>(
                  value: session.kioskId,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final k in session.kiosks)
                      DropdownMenuItem(
                        value: k.id,
                        child: Text(k.name, style: text.titleMedium),
                      ),
                  ],
                  onChanged: (id) => id == null ? null : session.selectKiosk(id),
                ),
              )
            else
              Text(session.kioskName, style: text.titleMedium),
            const Spacer(),
            if (user != null) ...[
              UserAvatar(name: user.displayName, photoUrl: user.photoUrl, size: 32),
              const SizedBox(width: AppSpacing.xs),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: text.labelLarge),
                  Text(
                    session.isAdmin ? 'Quản trị viên' : 'Nhân viên kiosk',
                    style: text.bodyMedium?.copyWith(color: colors.muted),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton.icon(
                onPressed: session.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
