import 'package:breakbite/app.dart';
import 'package:breakbite/config/firebase_dependencies.dart';
import 'package:flutter/material.dart';

/// Entry point with real Firebase. The fake-data build for building screens: `dev/main_dev.dart` (outside `lib/`,
/// so it never ends up in the submitted build).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BreakBiteApp(dependencies: await createFirebaseDependencies()));
}
