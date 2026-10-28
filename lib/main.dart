import 'package:flutter/material.dart';

import 'app.dart';
import 'dev/dev_services.dart';
import 'firebase/bootstrap.dart';
import 'models/models.dart';
import 'services/app_services.dart';

/// `--dart-define=USE_DEV_SERVICES=true` dùng service giả trong bộ nhớ để dựng màn khi
/// Firebase chưa nối. Gỡ cờ này và xoá `lib/dev/` trước khi nộp (task T83).
const _useDevServices = bool.fromEnvironment('USE_DEV_SERVICES');

/// Chỉ có tác dụng với service giả: `DEV_SIGNED_IN=true` vào thẳng app mà không qua S26,
/// `DEV_ROLE=staff` vào app người bán (mặc định là khách).
const _devSignedIn = bool.fromEnvironment('DEV_SIGNED_IN');
const _devRole = String.fromEnvironment('DEV_ROLE', defaultValue: 'user');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppServices services = _useDevServices
      ? createDevServices(role: _devRole == 'staff' ? UserRole.staff : UserRole.user, signedIn: _devSignedIn)
      : await bootstrapFirebase();
  runApp(BreakBiteApp(services: services));
}
