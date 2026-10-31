import 'package:flutter/material.dart';

import 'app.dart';
import 'config/firebase_dependencies.dart';

/// Bản chạy với Firebase thật. Bản dữ liệu giả để dựng màn: `dev/main_dev.dart` (nằm ngoài `lib/`,
/// nên không bao giờ lọt vào bản build nộp).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BreakBiteApp(dependencies: await createFirebaseDependencies()));
}
