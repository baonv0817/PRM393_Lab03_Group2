import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/motion.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';

/// The header and padding every web admin screen shares.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.title, this.subtitle, this.actions = const [], required this.child});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  /// Below this width the actions move under the title.
  static const _stackBelow = 860.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Reveal(
            rise: 6,
            duration: const Duration(milliseconds: 320),
            child: LayoutBuilder(
              builder: (context, box) {
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(title, style: text.headlineMedium)),
                    if (subtitle != null)
                      Text(subtitle!, style: text.bodyMedium?.copyWith(color: context.appColors.muted)),
                  ],
                );
                // On a narrow window the filters go under the title instead of squeezing it into a column of letters.
                if (box.maxWidth < _stackBelow && actions.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actions,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    ...actions,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A white panel with the Lab 2 card radius, for the two columns of the wide-screen layout.
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.md)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Padding(padding: padding, child: child),
  );
}

/// Shows the outcome of [command] once as a snackbar: [success] when it worked, the error message otherwise.
void showCommandResult(BuildContext context, Command<Object?> command, {required String success}) {
  final result = command.result;
  if (result == null) return;
  final message = switch (result) {
    Ok() => success,
    Err(:final error) => error.message,
  };
  command.clearResult();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, width: 480));
}
