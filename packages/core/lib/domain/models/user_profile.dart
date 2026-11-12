import 'package:breakbite_core/domain/models/order.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.studentId,
    this.phone,
    this.defaultKioskId,
    this.defaultPaymentMethod,
  });

  static const maxNameLength = 60;
  static final _studentId = RegExp(r'^[A-Z]{2}[0-9]{6}$');
  static final _phone = RegExp(r'^0[0-9]{9}$');

  final String uid;
  final String displayName;
  final String? email;
  final String? studentId;
  final String? phone;
  final String? defaultKioskId;
  final PaymentMethod? defaultPaymentMethod;

  static String normalizeName(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String normalizeStudentId(String value) => value.replaceAll(RegExp(r'\s'), '').toUpperCase();

  static String normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[\s.\-()]'), '');
    return digits.startsWith('+84') ? '0${digits.substring(3)}' : digits;
  }

  static String? nameProblem(String value) {
    final name = normalizeName(value);
    if (name.isEmpty) return 'Nhập họ tên.';
    if (name.length > maxNameLength) return 'Họ tên tối đa $maxNameLength ký tự.';
    return null;
  }

  static String? studentIdProblem(String value) {
    final id = normalizeStudentId(value);
    if (id.isEmpty || _studentId.hasMatch(id)) return null;
    return 'MSSV gồm 2 chữ cái và 6 chữ số, ví dụ SE183398.';
  }

  static String? phoneProblem(String value) {
    final phone = normalizePhone(value);
    if (phone.isEmpty || _phone.hasMatch(phone)) return null;
    return 'Số điện thoại gồm 10 chữ số, bắt đầu bằng 0.';
  }
}
