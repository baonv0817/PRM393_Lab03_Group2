import 'package:breakbite_core/domain/models/models.dart';

/// The words the admin website uses for the roles.
String roleLabel(UserRole role) => switch (role) {
  UserRole.user => 'Khách',
  UserRole.staff => 'Nhân viên',
  UserRole.admin => 'Quản trị',
};
