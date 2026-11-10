import 'package:breakbite/app.dart';
import 'package:breakbite/config/firebase_dependencies.dart';
import 'package:breakbite/ui/seller_orders/widgets/qr_camera_view.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BreakBiteApp(dependencies: await createFirebaseDependencies(), qrCamera: mobileScannerCamera));
}
