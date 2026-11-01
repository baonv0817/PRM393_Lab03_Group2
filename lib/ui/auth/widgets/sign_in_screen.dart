import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/theme/app_colors.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const AppTopBar(title: 'Đăng nhập'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppRadius.sheet),
                        ),
                        child: Icon(Icons.person, size: 40, color: colors.primaryText, semanticLabel: 'Tài khoản'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Đăng nhập bằng Google', style: text.headlineSmall, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Dùng tài khoản Google để đặt món, theo dõi đơn và giữ món yêu thích trên mọi máy.',
                        style: text.bodyMedium?.copyWith(color: colors.muted),
                        textAlign: TextAlign.center,
                      ),
                      if (auth.message case final message?) ...[
                        const SizedBox(height: AppSpacing.lg),
                        TestId(
                          's26.error',
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(AppRadius.input),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.error_outline, color: scheme.onErrorContainer),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: text.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                                    ),
                                  ),
                                ],
                              ),
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
                    's26.google',
                    child: AppButton(
                      label: auth.signIn.running ? 'Đang đăng nhập…' : 'Đăng nhập bằng Google',
                      icon: Icons.login,
                      loading: auth.signIn.running,
                      onPressed: auth.signIn.execute,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
