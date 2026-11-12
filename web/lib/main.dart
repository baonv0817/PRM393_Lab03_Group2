import 'package:breakbite_admin/app.dart';
import 'package:breakbite_admin/config/dependencies.dart';
import 'package:breakbite_admin/config/firebase_setup.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(MultiProvider(providers: firebaseProviders(), child: const AdminApp()));
}
