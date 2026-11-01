import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/profile/view_models/profile_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _entries = [
    (id: 'info', icon: Icons.badge_outlined, label: 'Hồ sơ sinh viên', path: AppRoutes.profileInfo),
    (id: 'payment', icon: Icons.credit_card, label: 'Phương thức thanh toán', path: AppRoutes.profilePayment),
    (
      id: 'notifications',
      icon: Icons.notifications_none,
      label: 'Cài đặt thông báo',
      path: AppRoutes.profileNotifications,
    ),
    (id: 'favorites', icon: Icons.favorite_border, label: 'Món yêu thích', path: AppRoutes.favorites),
    (id: 'history', icon: Icons.receipt_long, label: 'Lịch sử đơn', path: AppRoutes.ordersHistory),
    (id: 'firebaseDemo', icon: Icons.science_outlined, label: 'Khu demo Firebase', path: AppRoutes.firebaseDemo),
  ];

  Future<void> _confirmSignOut(BuildContext context, AuthViewModel auth) async {
    final confirmed = await showAppDialog(
      context,
      title: 'Đăng xuất?',
      message: 'Dữ liệu tạm trên máy này sẽ được xoá. Giỏ hàng và đơn hàng vẫn lưu trong tài khoản của bạn.',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (confirmed != true) return;
    final result = await auth.signOut.execute();
    if (!context.mounted) return;
    if (result case Err(:final error)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final profile = context.watch<ProfileViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final user = auth.user;

    return Scaffold(
      appBar: const AppTopBar(title: 'Cá nhân'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _Section(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.surfaceVariant,
                    child: Icon(Icons.person, color: colors.primaryText, semanticLabel: 'Ảnh đại diện'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? 'Khách', style: text.titleMedium),
                        const SizedBox(height: AppSpacing.xxs),
                        TestId(
                          's15.orderCount',
                          child: Text(profile.orderCountLabel, style: text.bodyMedium?.copyWith(color: colors.muted)),
                        ),
                      ],
                    ),
                  ),
                  if (profile.orderCount is ViewError<int>)
                    TestId(
                      's15.retry',
                      child: AppIconButton(
                        icon: Icons.refresh,
                        semanticLabel: 'Tải lại số đơn',
                        onPressed: profile.load,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            child: Column(
              children: [
                for (final (index, entry) in _entries.indexed) ...[
                  if (index > 0)
                    Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: colors.border),
                  TestId(
                    's15.${entry.id}',
                    child: ListTile(
                      minTileHeight: AppA11y.minTouchTarget + AppSpacing.xs,
                      leading: Icon(entry.icon, color: colors.primaryText),
                      title: Text(entry.label, style: text.bodyLarge),
                      trailing: Icon(Icons.chevron_right, color: colors.muted),
                      onTap: () => context.push(entry.path),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: ListenableBuilder(
              listenable: auth.signOut,
              builder: (context, _) => TestId(
                's15.signOut',
                child: TextButton.icon(
                  onPressed: auth.signOut.running ? null : () => _confirmSignOut(context, auth),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    minimumSize: const Size(AppA11y.minTouchTarget, AppA11y.minTouchTarget),
                  ),
                  icon: const Icon(Icons.logout),
                  label: Text(auth.signOut.running ? 'Đang đăng xuất…' : 'Đăng xuất'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: context.appColors.border),
    ),
    child: child,
  );
}
