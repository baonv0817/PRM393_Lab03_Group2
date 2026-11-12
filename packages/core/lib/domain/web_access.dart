import 'package:breakbite_core/domain/models/app_user.dart';

/// Who may use the web admin: staff with a kiosk, and admins. Returns the Vietnamese message the sign-in screen
/// shows to anyone else, or `null` when [user] may continue. The Security Rules enforce the same split on every
/// write; this check only stops a customer account from reaching screens that would fail anyway.
String? webAdminAccessProblem(AppUser user) => switch (user.role) {
  UserRole.admin => null,
  UserRole.staff when (user.kioskId ?? '').isNotEmpty => null,
  UserRole.staff =>
    'Tài khoản nhân viên ${_who(user)} chưa được gán kiosk. Nhờ quản trị viên gán kiosk rồi đăng nhập lại.',
  UserRole.user =>
    'Tài khoản ${_who(user)} là tài khoản khách hàng. Trang quản trị chỉ dành cho nhân viên kiosk và quản trị viên; '
        'khách hàng đặt món trên ứng dụng BreakBite.',
};

String _who(AppUser user) => (user.email ?? '').isNotEmpty ? user.email! : user.displayName;
