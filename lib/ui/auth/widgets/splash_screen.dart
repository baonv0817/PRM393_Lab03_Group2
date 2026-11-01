import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'BreakBite đang mở',
          liveRegion: true,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BreakBiteLogo(size: 96),
              SizedBox(height: AppSpacing.lg),
              SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            ],
          ),
        ),
      ),
    );
  }
}
