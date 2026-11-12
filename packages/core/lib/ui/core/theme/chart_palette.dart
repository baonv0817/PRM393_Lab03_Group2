import 'package:flutter/material.dart';

/// Colours of the charts of the admin site. One accent (the brand orange) comes first; the others are muted so a
/// chart with several series still reads as one family. Each pair has enough contrast on the white card.
abstract final class ChartPalette {
  /// Series, in order: one per kiosk in a stacked chart.
  static const series = [Color(0xFFF69D39), Color(0xFF2F7F79), Color(0xFF57534E), Color(0xFF7FA8C9), Color(0xFFC7BBA9)];

  /// The colour of series [index]; the palette repeats after its last colour.
  static Color seriesAt(int index) => series[index % series.length];

  /// The bars of a chart that are not the one to look at.
  static const quiet = Color(0xFFE4DFD8);
}
