import 'package:breakbite_core/domain/credentials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Credentials', () {
    test('an email needs an @ and a domain, and spaces around it do not matter', () {
      expect(Credentials.emailProblem(''), 'Nhập email.');
      expect(Credentials.emailProblem('abc'), contains('chưa đúng dạng'));
      expect(Credentials.emailProblem('a@b'), contains('chưa đúng dạng'));
      expect(Credentials.emailProblem('a b@c.vn'), contains('chưa đúng dạng'));
      expect(Credentials.emailProblem('  ten@fpt.edu.vn  '), isNull);
    });

    test('a new password needs 8 to 64 characters with a letter and a digit', () {
      expect(Credentials.newPasswordProblem(''), 'Nhập mật khẩu.');
      expect(Credentials.newPasswordProblem('abc123'), contains('ít nhất 8'));
      expect(Credentials.newPasswordProblem('abcdefgh'), contains('chữ và số'));
      expect(Credentials.newPasswordProblem('12345678'), contains('chữ và số'));
      expect(Credentials.newPasswordProblem('a1${'x' * 70}'), contains('tối đa'));
      expect(Credentials.newPasswordProblem('breakbite1'), isNull);
    });

    test('signing in only asks for something typed', () {
      expect(Credentials.passwordProblem(''), 'Nhập mật khẩu.');
      expect(Credentials.passwordProblem('a'), isNull);
      expect(Credentials.signInProblem('x', 'y'), contains('Email'));
      expect(Credentials.signInProblem('a@b.vn', ''), 'Nhập mật khẩu.');
      expect(Credentials.signInProblem('a@b.vn', 'y'), isNull);
    });

    test('a name is needed and is at most 60 characters; a registration reports the first problem', () {
      expect(Credentials.nameProblem('  '), 'Nhập tên của bạn.');
      expect(Credentials.nameProblem('x' * 61), contains('tối đa'));
      expect(Credentials.registerProblem('', 'bad', 'x'), 'Nhập tên của bạn.');
      expect(Credentials.registerProblem('Quân', 'bad', 'x'), contains('Email'));
      expect(Credentials.registerProblem('Quân', 'q@fpt.edu.vn', 'x'), contains('ít nhất 8'));
      expect(Credentials.registerProblem('Quân', 'q@fpt.edu.vn', 'breakbite1'), isNull);
    });
  });
}
