/// Render animation strip metadata shared between Core and Render.
library;

import '../snapshots/enums.dart';
import '../util/vec2.dart';

/// Data-driven animation strip definition (frame size, paths, timing).
class RenderAnimSetDefinition {
  const RenderAnimSetDefinition({
    required this.frameWidth,
    required this.frameHeight,
    required this.sourcesByKey,
    this.rowByKey = const <AnimKey, int>{},
    this.anchorInFramePx,
    this.frameStartByKey = const <AnimKey, int>{},
    this.gridColumnsByKey = const <AnimKey, int>{},
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

  /// Optional anchor/pivot location inside a single source frame (in pixels).
  ///
  /// When null, render uses `Anchor.center`.
  ///
  /// This is useful when the authored art is not centered on the logical
  /// collider (e.g. enemies with long weapons/tails). The renderer treats the
  /// Core snapshot position as the world-space position of this anchor.
  final Vec2? anchorInFramePx;

  /// Optional 0-based frame start offset per [AnimKey] for strip reuse.
  ///
  /// Defaults to 0 (start of the strip). Use this when multiple animations
  /// share a single horizontal strip but start at different frame indices.
  final Map<AnimKey, int> frameStartByKey;

  /// Optional sheet column count per [AnimKey] for row-wrapped animations.
  ///
  /// When present for a key, [frameStartByKey] is treated as a start column and
  /// frame sampling wraps to following rows using this column count.
  final Map<AnimKey, int> gridColumnsByKey;

  final Map<AnimKey, int> frameCountsByKey;
  final Map<AnimKey, double> stepTimeSecondsByKey;
}
