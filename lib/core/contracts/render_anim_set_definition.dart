/// Render animation strip metadata shared between Core and Render.
library;

import '../snapshots/enums.dart';

/// Data-driven animation strip definition (frame size, paths, timing).
class RenderAnimSetDefinition {
  const RenderAnimSetDefinition({
    required this.frameWidth,
    required this.frameHeight,
    required this.sourcesByKey,
    this.rowByKey = const <AnimKey, int>{},
    required this.frameCountsByKey,
    required this.stepTimeSecondsByKey,
  });

  final int frameWidth;
  final int frameHeight;

  /// Asset paths (relative to `assets/images/`) for each animation source.
  ///
  /// A single path can be reused for multiple keys:
  /// - **Strip format**: each key points to a single-row horizontal strip (row 0).
  /// - **Sheet format**: multiple keys point to one multi-row sheet, using
  ///   [rowByKey] to select the row for each [AnimKey].
  final Map<AnimKey, String> sourcesByKey;

  /// Optional 0-based row index per [AnimKey] when using a multi-row sheet.
  ///
  /// If a key is missing, render assumes row 0 (strip compatibility).
  final Map<AnimKey, int> rowByKey;

  final Map<AnimKey, int> frameCountsByKey;
  final Map<AnimKey, double> stepTimeSecondsByKey;
}
