import 'package:breakbite_core/domain/models/app_user.dart';

/// The web admin's address, shown to an admin who signs in to the mobile app.
const webAdminUrl = 'https://breakbite-1315b.web.app';

/// Who may use the mobile app: customers (the ordering app) and kiosk staff (the seller app). An admin manages the
/// whole system from the web admin, so the app turns the account away with this Vietnamese message instead of
/// opening seller screens that have no kiosk. Returns `null` when [user] may continue. The web admin has the
/// mirror rule ([webAdminAccessProblem] in web_access.dart).
String? mobileAccessProblem(AppUser user) => switch (user.role) {
  UserRole.user || UserRole.staff => null,
  UserRole.admin =>
    'Tài khoản ${(user.email ?? '').isNotEmpty ? user.email! : user.displayName} là tài khoản quản trị viên. '
        'Quản trị viên làm việc trên trang web quản trị $webAdminUrl; ứng dụng này dành cho khách hàng và nhân viên '
        'kiosk.',
};
