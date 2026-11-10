import 'package:breakbite/ui/auth/view_models/auth_view_model.dart';
import 'package:breakbite/ui/core/theme/app_dimens.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Asks first, then signs out; a failure comes back as a message. [message] says what signing out costs.
Future<void> confirmSignOut(
  BuildContext context, {
  String message = 'Dữ liệu tạm trên máy này sẽ được xoá. Giỏ hàng và đơn hàng vẫn lưu trong tài khoản của bạn.',
}) async {
  final auth = context.read<AuthViewModel>();
  final confirmed = await showAppDialog(
    context,
    title: 'Đăng xuất?',
    message: message,
    confirmLabel: 'Đăng xuất',
    destructive: true,
  );
  if (confirmed != true) return;
  final result = await auth.signOut.execute();
  if (!context.mounted) return;
  if (result case Err(:final error)) {
    showAppMessage(context, error.message);
  }
}

class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key, required this.testId});

  final String testId;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthViewModel>();
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: auth.signOut,
      builder: (context, _) => TestId(
        testId,
        child: TextButton.icon(
          onPressed: auth.signOut.running ? null : () => confirmSignOut(context),
          style: TextButton.styleFrom(
            foregroundColor: scheme.error,
            minimumSize: const Size(AppA11y.minTouchTarget, AppA11y.minTouchTarget),
          ),
          icon: const Icon(Icons.logout),
          label: Text(auth.signOut.running ? 'Đang đăng xuất…' : 'Đăng xuất'),
        ),
      ),
    );
  }
}
