import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Temporary screen until the owner finishes the real one. Replace it with the real screen in
/// `lib/router/routes_pX.dart`; delete this screen once every route has a real screen.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.code,
    required this.title,
    required this.owner,
    this.showBack = true,
  });

  final String code;
  final String title;
  final String owner;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppTopBar(
        title: title,
        onBack: showBack && Navigator.of(context).canPop() ? () => Navigator.of(context).maybePop() : null,
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
