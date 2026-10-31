import 'package:breakbite/app.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:flutter/material.dart';

import 'fake_dependencies.dart';

/// Chạy app với dữ liệu giả: `flutter run -t dev/main_dev.dart` (VS Code: F5 các cấu hình "fake data").
/// `--dart-define=DEV_SIGNED_IN=true` vào thẳng app không qua S26; `DEV_ROLE=staff` vào app người bán.
const _devSignedIn = bool.fromEnvironment('DEV_SIGNED_IN');
const _devRole = String.fromEnvironment('DEV_ROLE', defaultValue: 'user');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    BreakBiteApp(
      dependencies: createFakeDependencies(
        role: _devRole == 'staff' ? UserRole.staff : UserRole.user,
        signedIn: _devSignedIn,
      ),
    ),
  );
}
