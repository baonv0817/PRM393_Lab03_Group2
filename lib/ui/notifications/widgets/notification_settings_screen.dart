import 'package:breakbite/routing/routes.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/ui/notifications/view_models/notification_settings_view_model.dart';
import 'package:breakbite/ui/profile/widgets/profile_section.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// S18: four switches. Each one is saved as soon as it is flipped; there is no save button.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _flip(
    BuildContext context,
    NotificationSettingsViewModel vm,
    NotificationSwitch option,
    bool value,
  ) async {
    final result = await vm.set(option, value);
    if (!context.mounted) return;
    if (result case Err(:final error)) showAppMessage(context, error.message);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationSettingsViewModel>();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppTopBar(
        title: 'Cài đặt thông báo',
        onBack: () => context.canPop() ? context.pop() : context.go(AppRoutes.profile),
      ),
      body: switch (vm.state) {
        ViewLoading() => const LoadingView(message: 'Đang tải cài đặt…'),
        ViewError(:final message) => TestId(
          's18.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewEmpty() => const SizedBox.shrink(),
        ViewData() => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                ProfileSection(
                  child: Column(
                    children: [
                      for (final (i, option) in NotificationSwitch.values.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        TestId(
                          's18.${option.name}',
                          child: MergeSemantics(
                            child: SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xxs,
                              ),
                              title: Text(option.title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              subtitle: Text(option.subtitle),
                              value: vm.valueOf(option),
                              onChanged: vm.saving ? null : (value) => _flip(context, vm, option, value),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Thông báo đẩy khi app đang đóng cần bạn cho phép thông báo trong cài đặt của điện thoại.',
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      },
    );
  }
}
