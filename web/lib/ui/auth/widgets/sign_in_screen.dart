import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/brand.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:breakbite_core/ui/core/widgets/email_auth_form.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// W01 Sign-in: Google Sign-In; customer accounts and staff without a kiosk are turned away with the reason.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    final command = session.signIn;
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final error = session.rejection ?? command.result?.errorOrNull?.message;
    return Scaffold(
      backgroundColor: colors.selected,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ListenableBuilder(
                  listenable: Listenable.merge([command, session.signInWithEmail, session.register]),
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BreakBiteLogo(size: 88),
                      const SizedBox(height: AppSpacing.md),
                      Text('BreakBite · Quản trị', style: text.headlineMedium, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Dành cho nhân viên kiosk và quản trị viên. Đăng nhập bằng email hoặc tài khoản Google đã được cấp quyền.',
                        style: text.bodyMedium?.copyWith(color: colors.muted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (error != null && !command.running) ...[
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(AppRadius.input),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.block, color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(child: Text(error, style: text.bodyMedium)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      EmailAuthForm(
                        idPrefix: 'w01',
                        running: session.signInWithEmail.running || session.register.running,
                        onSignIn: (email, password) =>
                            session.signInWithEmail.execute((email: email, password: password)),
                        onRegister: (name, email, password) =>
                            session.register.execute((name: name, email: email, password: password)),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          variant: AppButtonVariant.secondary,
                          label: 'Đăng nhập với Google',
                          icon: Icons.login,
                          large: true,
                          loading: command.running,
                          onPressed: command.running ? null : () => command.execute(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
