import 'dart:io';

import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('BreakBiteLogo renders the SVG at the right size with an accessibility label', (tester) async {
    await tester.pumpWidget(host(const BreakBiteLogo(size: 120)));
    await tester.pump();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.getSize(find.byType(SvgPicture)), const Size(120, 120));
    expect(find.bySemanticsLabel('Logo BreakBite'), findsOneWidget);
  });

  testWidgets('both logo variants load', (tester) async {
    for (final v in LogoVariant.values) {
      await tester.pumpWidget(host(BreakBiteLogo(size: 72, variant: v)));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: v.name);
    }
  });

  testWidgets('BreakBiteWordmark shows the BreakBite name with "Bite" in the accent color', (tester) async {
    await tester.pumpWidget(host(const BreakBiteWordmark()));
    expect(find.bySemanticsLabel('BreakBite'), findsOneWidget);
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    expect(rich.text.toPlainText(), 'BreakBite');
  });

  test('Android app icon replaces the default Flutter icon', () {
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(File('android/app/src/main/res/mipmap-$d/ic_launcher.png').existsSync(), isTrue, reason: d);
      expect(
        File('android/app/src/main/res/mipmap-$d/ic_launcher_foreground.png').existsSync(),
        isTrue,
        reason: 'adaptive $d',
      );
    }
    final adaptive = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(adaptive, contains('@color/ic_launcher_background'));
    expect(adaptive, contains('@mipmap/ic_launcher_foreground'));
    expect(File('android/app/src/main/res/values/ic_launcher_background.xml').readAsStringSync(), contains('#F69D39'));
    expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(), contains('android:label="BreakBite"'));
  });
}
