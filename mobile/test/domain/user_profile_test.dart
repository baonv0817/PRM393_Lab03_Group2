import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names are trimmed, required and at most 60 characters', () {
    expect(UserProfile.normalizeName('  Nguyễn   Minh  Quân '), 'Nguyễn Minh Quân');
    expect(UserProfile.nameProblem('   '), 'Nhập họ tên.');
    expect(UserProfile.nameProblem('a' * 61), 'Họ tên tối đa 60 ký tự.');
    expect(UserProfile.nameProblem('Quân'), isNull);
  });

  test('a student ID is optional, upper-cased, two letters then six digits', () {
    expect(UserProfile.normalizeStudentId(' se 183398 '), 'SE183398');
    expect(UserProfile.studentIdProblem(''), isNull);
    expect(UserProfile.studentIdProblem('se183398'), isNull);
    expect(UserProfile.studentIdProblem('SE1833'), isNotNull);
    expect(UserProfile.studentIdProblem('183398SE'), isNotNull);
  });

  test('a phone number is optional, accepts +84 and separators, and has 10 digits starting with 0', () {
    expect(UserProfile.normalizePhone('+84 912.345.678'), '0912345678');
    expect(UserProfile.phoneProblem(''), isNull);
    expect(UserProfile.phoneProblem('0912 345 678'), isNull);
    expect(UserProfile.phoneProblem('912345678'), isNotNull);
    expect(UserProfile.phoneProblem('09123456789'), isNotNull);
  });
}
