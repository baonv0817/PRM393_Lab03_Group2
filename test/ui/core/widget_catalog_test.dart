import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/widget_catalog.dart';

/// T21: the widget catalog at the two phone widths of the handout, at normal and large text.
void main() {
  for (final width in const [360.0, 412.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('every shared widget fits at $width dp with text × $scale', (tester) async {
        final handle = tester.ensureSemantics();
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = Size(width, 800);
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(const WidgetCatalogApp());
        await tester.pump(const Duration(milliseconds: 100));

        final scrollable = find.byType(Scrollable).first;
        var pages = 0;
        while (true) {
          expect(tester.takeException(), isNull, reason: 'overflow or build error on page $pages');
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          if (scale == 1.0) await expectLater(tester, meetsGuideline(textContrastGuideline));
          final position = tester.state<ScrollableState>(scrollable).position;
          if (position.pixels >= position.maxScrollExtent || pages > 30) break;
          await tester.drag(scrollable, const Offset(0, -500));
          await tester.pump(const Duration(milliseconds: 100));
          pages++;
        }
        expect(pages, greaterThan(3), reason: 'the catalog is long enough to cover every widget');
        handle.dispose();
      });
    }
  }
}
