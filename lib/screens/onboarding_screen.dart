import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/widgets.dart';

/// S01 Onboarding theo Figma v2: màn đầu tiên của người chưa đăng nhập.
/// "Bỏ qua", "Bắt đầu đặt món" và liên kết đăng nhập đều đánh dấu đã xem Onboarding; router tự
/// đưa người dùng sang màn đăng nhập (S26) vì app bắt buộc đăng nhập (sai lệch D03).
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
              Row(
                children: [
                  Icon(Icons.location_on, color: colors.muted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Campus Q9 · Tầng 2', style: text.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  AppButton(label: 'Bỏ qua', variant: AppButtonVariant.text, onPressed: done),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(28)),
                        child: Icon(Icons.restaurant, size: 56, color: colors.primaryText),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Semantics(
                        header: true,
                        child: Text(
                          'Nạp năng lượng nhanh trong 15 phút giải lao',
                          textAlign: TextAlign.center,
                          style: text.headlineMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.w800, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Đặt trước từ lớp học, nhận tại Kiosk Q9 · Tầng 2. Không phải xếp hàng.',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(color: colors.muted),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _BenefitsCard(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
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

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  static const _rows = [
    (Icons.schedule, 'Chuẩn bị dự kiến 3–5 phút'),
    (Icons.qr_code_2, 'Đặt trước, quét mã nhận món'),
    (Icons.credit_card, 'Trả bằng ví hoặc tiền mặt'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          children: [
            for (final (icon, label) in _rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(icon, color: colors.primaryText),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(label, style: text.bodyLarge)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
