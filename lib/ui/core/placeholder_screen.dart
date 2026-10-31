import 'package:flutter/material.dart';

import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';

/// Màn tạm cho tới khi người phụ trách làm xong. Thay bằng màn thật trong
/// `lib/router/routes_pX.dart`; xoá màn này khi mọi route đã có màn thật.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.code, required this.title, required this.owner, this.showBack = true});

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
