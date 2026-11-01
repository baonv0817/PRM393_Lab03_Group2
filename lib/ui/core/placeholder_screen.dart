import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.code,
    required this.title,
    required this.owner,
    this.showBack = true,
    this.onExit,
  });

  final String code;
  final String title;
  final String owner;
  final bool showBack;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppTopBar(
        title: title,
        closes: !canPop,
        onBack: !showBack
            ? null
            : canPop
            ? () => Navigator.of(context).maybePop()
            : onExit,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(code, style: text.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(title, style: text.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              Text('Chưa làm · phụ trách $owner', style: text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
