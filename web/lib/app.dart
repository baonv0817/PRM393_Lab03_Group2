import 'package:breakbite_admin/routing/router.dart';
import 'package:breakbite_admin/ui/shell/view_models/admin_session.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final GoRouter _router = buildRouter(context.read<AdminSession>());

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'BreakBite · Quản trị',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    routerConfig: _router,
  );
}
