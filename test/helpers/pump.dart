import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Phone widths the Lab 2 accessibility checklist asks for.
abstract final class TestScreens {
  static const narrow = Size(360, 800);
  static const wide = Size(412, 915);
}

/// Pumps [screen] the way the app shows it: app theme, the given [providers] above it, a phone of
/// [size] logical pixels (360 dp by default). Restores the test view afterwards.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<SingleChildWidget> providers = const [],
  Size size = TestScreens.narrow,
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final app = MaterialApp(theme: AppTheme.light(), home: screen);
  await tester.pumpWidget(providers.isEmpty ? app : MultiProvider(providers: providers, child: app));
  if (settle) await tester.pumpAndSettle();
}
