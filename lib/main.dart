import 'package:flutter/material.dart';

import 'app.dart';
import 'dev/dev_services.dart';
import 'firebase/bootstrap.dart';
import 'services/app_services.dart';

/// `--dart-define=USE_DEV_SERVICES=true` dùng service giả trong bộ nhớ để dựng màn khi
/// Firebase chưa nối. Gỡ cờ này và xoá `lib/dev/` trước khi nộp (task T83).
const _useDevServices = bool.fromEnvironment('USE_DEV_SERVICES');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppServices services = _useDevServices ? createDevServices() : await bootstrapFirebase();
  runApp(BreakBiteApp(services: services));
}
