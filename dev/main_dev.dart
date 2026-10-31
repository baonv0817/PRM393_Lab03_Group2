import 'package:breakbite/app.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:flutter/material.dart';

import 'fake_dependencies.dart';

/// Runs the app with fake data: `flutter run -t dev/main_dev.dart` (VS Code: F5 with the "fake data" configs).
/// `--dart-define=DEV_SIGNED_IN=true` skips S26 and enters the app; `DEV_ROLE=staff` opens the seller app.
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
