import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// K01: staff sign-in. Figma asks for a counter code and a PIN; the app signs staff in with Google like
/// customers (D31) and the account's `role` decides which app opens, so there is no PIN to keep or reset.
class SellerSignInScreen extends StatelessWidget {
  const SellerSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xl * 2),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppRadius.sheet),
                        ),
                        child: Icon(
                          Icons.restaurant,
                          size: 40,
                          color: colors.primaryText,
                          semanticLabel: 'BreakBite Kiosk',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('BreakBite Kiosk', style: text.headlineSmall, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Dành cho nhân viên quầy. Đăng nhập bằng tài khoản Google đã được quản trị viên cấp quyền.',
                        style: text.bodyMedium?.copyWith(color: colors.muted),
                        textAlign: TextAlign.center,
                      ),
                      if (auth.message case final message?) ...[
                        const SizedBox(height: AppSpacing.lg),
                        TestId(
                          'k01.error',
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(AppRadius.input),
                              ),
                              child: Text(message, style: text.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ListenableBuilder(
                  listenable: auth.signIn,
                  builder: (context, _) => TestId(
                    'k01.google',
                    child: AppButton(
                      label: auth.signIn.running ? 'Đang đăng nhập…' : 'Đăng nhập bằng Google',
                      icon: Icons.login,
                      loading: auth.signIn.running,
                      onPressed: auth.signIn.execute,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Quên quyền truy cập? Liên hệ quản lý',
                style: text.bodyMedium?.copyWith(color: colors.primaryText, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
