import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// S01 Onboarding: the first screen for signed-out users, with only the BreakBite brand, a one-line
/// intro and the way in. "Bỏ qua", "Bắt đầu đặt món" and the sign-in link all mark Onboarding as
/// seen; the router then sends the user to sign-in (S26) because the app requires sign-in (D03).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthViewModel>();
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final done = auth.completeOnboarding;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TestId(
                  's01.skip',
                  child: AppButton(label: 'Bỏ qua', variant: AppButtonVariant.text, onPressed: done),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BreakBiteLogo(size: 144),
                        const SizedBox(height: AppSpacing.lg),
                        const BreakBiteWordmark(fontSize: 40),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Nạp năng lượng nhanh trong 15 phút giải lao',
                          textAlign: TextAlign.center,
                          style: text.titleMedium?.copyWith(color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TestId(
                  's01.start',
                  child: AppButton(label: 'Bắt đầu đặt món', onPressed: done),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              TestId(
                's01.signIn',
                child: AppButton(label: 'Đăng nhập bằng Google', variant: AppButtonVariant.text, onPressed: done),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}
