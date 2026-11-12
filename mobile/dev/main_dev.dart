import 'package:breakbite/app.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:flutter/material.dart';

import 'dev_seed.dart';
import 'fake_dependencies.dart';

/// Runs the app with fake data: `flutter run -t dev/main_dev.dart` (VS Code: F5 with the "fake data" configs).
/// `--dart-define=DEV_SIGNED_IN=true` skips S26 and enters the app; `DEV_ROLE=staff` opens the seller app.
const _devSignedIn = bool.fromEnvironment('DEV_SIGNED_IN');
const _devRole = String.fromEnvironment('DEV_ROLE', defaultValue: 'user');

/// `--dart-define=DEV_SEED=true` adds a few orders of the fake customer, see [seedDevOrders].
const _devSeed = bool.fromEnvironment('DEV_SEED');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = createFakeDependencies(
    role: _devRole == 'staff' ? UserRole.staff : UserRole.user,
    signedIn: _devSignedIn,
    // Seeded orders are placed this morning, so the shift statistics and "Tuần này" have them whatever the date.
    orderClock: _devSeed ? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 8) : null,
  );
  if (_devSeed) await seedDevOrders(dependencies);
  runApp(BreakBiteApp(dependencies: dependencies));
}
