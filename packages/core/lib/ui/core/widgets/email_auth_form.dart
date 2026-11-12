import 'package:breakbite_core/domain/credentials.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:breakbite_core/ui/core/widgets/inputs.dart';
import 'package:breakbite_core/ui/core/widgets/test_id.dart';
import 'package:flutter/material.dart';

/// Sign in or create an account with an email and a password, for people without a Google account. One form with
/// two modes. The problems under the fields show once the person has tried to send it; nothing is sent until
/// every field is valid. Test ids are `<idPrefix>.name`, `.email`, `.password`, `.submit` and `.mode`.
class EmailAuthForm extends StatefulWidget {
  const EmailAuthForm({
    super.key,
    required this.idPrefix,
    required this.running,
    required this.onSignIn,
    required this.onRegister,
  });

  final String idPrefix;

  /// A request is on its way: the button shows progress and cannot be pressed again.
  final bool running;
  final void Function(String email, String password) onSignIn;
  final void Function(String name, String email, String password) onRegister;

  @override
  State<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends State<EmailAuthForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _registering = false;
  var _attempted = false;
  var _hidden = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(bool registering) => setState(() {
    _registering = registering;
    _attempted = false;
  });

  void _submit() {
    final problem = _registering
        ? Credentials.registerProblem(_name.text, _email.text, _password.text)
        : Credentials.signInProblem(_email.text, _password.text);
    if (problem != null) {
      setState(() => _attempted = true);
      return;
    }
    if (_registering) {
      widget.onRegister(_name.text.trim(), _email.text.trim(), _password.text);
    } else {
      widget.onSignIn(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.idPrefix;
    String? shown(String? problem) => _attempted ? problem : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_registering) ...[
          TestId(
            '$id.name',
            child: AppTextField(
              label: 'Tên của bạn',
              controller: _name,
              prefixIcon: Icons.person_outline,
              errorText: shown(Credentials.nameProblem(_name.text)),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TestId(
          '$id.email',
          child: AppTextField(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
            errorText: shown(Credentials.emailProblem(_email.text)),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TestId(
          '$id.password',
          child: AppTextField(
            label: 'Mật khẩu',
            controller: _password,
            obscureText: _hidden,
            prefixIcon: Icons.lock_outline,
            helperText: _registering ? 'Ít nhất ${Credentials.minPasswordLength} ký tự, gồm chữ và số.' : null,
            errorText: shown(
              _registering
                  ? Credentials.newPasswordProblem(_password.text)
                  : Credentials.passwordProblem(_password.text),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() => _hidden = !_hidden),
            child: Text(_hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TestId(
          '$id.submit',
          child: AppButton(
            label: widget.running ? 'Đang xử lý…' : (_registering ? 'Tạo tài khoản' : 'Đăng nhập'),
            loading: widget.running,
            onPressed: widget.running ? null : _submit,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TestId(
          '$id.mode',
          child: AppButton(
            label: _registering ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Tạo tài khoản',
            variant: AppButtonVariant.text,
            onPressed: widget.running ? null : () => _setMode(!_registering),
          ),
        ),
      ],
    );
  }
}
