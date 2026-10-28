import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../viewmodels/view_state.dart';
import 'buttons.dart';

/// Loading của Lab 2.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Đang tải…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: message,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.iconColor, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final Color iconColor;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: colors.surfaceVariant, shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              liveRegion: true,
              child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: actionLabel!, onPressed: onAction, variant: AppButtonVariant.secondary),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty của Lab 2.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.actionLabel, this.onAction, this.icon = Icons.inbox_outlined});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _MessageView(
        icon: icon,
        iconColor: context.appColors.muted,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

/// Error của Lab 2: luôn có lối đi tiếp (thử lại).
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _MessageView(
        icon: Icons.error_outline,
        iconColor: Theme.of(context).colorScheme.error,
        message: message,
        actionLabel: 'Thử lại',
        onAction: onRetry,
      );
}

/// Vẽ một [ViewState]: loading, empty, error có thử lại, hoặc dữ liệu.
class ViewStateView<T> extends StatelessWidget {
  const ViewStateView({
    super.key,
    required this.state,
    required this.builder,
    required this.onRetry,
    this.emptyMessage = 'Chưa có dữ liệu',
  });

  final ViewState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => switch (state) {
        ViewLoading<T>() => const LoadingView(),
        ViewEmpty<T>(:final message) => EmptyView(message: message ?? emptyMessage),
        ViewError<T>(:final message) => ErrorView(message: message, onRetry: onRetry),
        ViewData<T>(:final data) => builder(context, data),
      };
}
