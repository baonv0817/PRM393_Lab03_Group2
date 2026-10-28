import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/widgets.dart';

/// S01 Onboarding: màn đầu tiên của người chưa đăng nhập, chỉ có thương hiệu BreakBite, một dòng
/// giới thiệu và lối vào. "Bỏ qua", "Bắt đầu đặt món" và liên kết đăng nhập đều đánh dấu đã xem
/// Onboarding; router tự đưa người dùng sang màn đăng nhập (S26) vì app bắt buộc đăng nhập (D03).
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
                child: AppButton(label: 'Bỏ qua', variant: AppButtonVariant.text, onPressed: done),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BreakBiteLogo(size: 144),
                        const SizedBox(height: AppSpacing.xl),
                        const BreakBiteWordmark(fontSize: 40),
                        const SizedBox(height: AppSpacing.md),
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
              SizedBox(width: double.infinity, child: AppButton(label: 'Bắt đầu đặt món', onPressed: done)),
              const SizedBox(height: AppSpacing.xs),
              AppButton(label: 'Đăng nhập bằng Google', variant: AppButtonVariant.text, onPressed: done),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
