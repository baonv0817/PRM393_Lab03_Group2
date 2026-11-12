import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:flutter/material.dart';

/// Lab 2 Loading.
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
            const SizedBox(height: AppSpacing.md),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: colors.surfaceVariant, shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: actionLabel!, onPressed: onAction, variant: AppButtonVariant.secondary),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lab 2 Empty.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

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

/// Lab 2 Error: always offers a way forward (retry).
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

/// Renders a [ViewState]: loading, empty, error with retry, or data.
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
