/// What a person types to sign in or to create an account with an email. The same checks run on the form (to
/// show the problem under the field) and in the view models (so nothing is sent with a wrong value).
abstract final class Credentials {
  static const minPasswordLength = 8;
  static const maxPasswordLength = 64;
  static const maxNameLength = 60;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// Why [email] cannot be used, or `null`.
  static String? emailProblem(String email) {
    final value = email.trim();
    if (value.isEmpty) return 'Nhập email.';
    if (!_email.hasMatch(value)) return 'Email chưa đúng dạng, ví dụ ten@gmail.com.';
    return null;
  }

  /// Why [password] cannot be used to create an account, or `null`.
  static String? newPasswordProblem(String password) {
    if (password.isEmpty) return 'Nhập mật khẩu.';
    if (password.length < minPasswordLength) return 'Mật khẩu cần ít nhất $minPasswordLength ký tự.';
    if (password.length > maxPasswordLength) return 'Mật khẩu tối đa $maxPasswordLength ký tự.';
    if (!RegExp('[A-Za-z]').hasMatch(password) || !RegExp('[0-9]').hasMatch(password)) {
      return 'Mật khẩu cần có cả chữ và số.';
    }
    return null;
  }

  /// Signing in only needs something typed: whether it is right is for the server to say.
  static String? passwordProblem(String password) => password.isEmpty ? 'Nhập mật khẩu.' : null;

  static String? nameProblem(String name) {
    final value = name.trim();
    if (value.isEmpty) return 'Nhập tên của bạn.';
    if (value.length > maxNameLength) return 'Tên tối đa $maxNameLength ký tự.';
    return null;
  }

  /// The first problem of a sign-in, or `null`.
  static String? signInProblem(String email, String password) => emailProblem(email) ?? passwordProblem(password);

  /// The first problem of a registration, or `null`.
  static String? registerProblem(String name, String email, String password) =>
      nameProblem(name) ?? emailProblem(email) ?? newPasswordProblem(password);
}
