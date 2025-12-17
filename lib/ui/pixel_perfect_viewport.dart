import 'dart:math';

import 'package:flutter/widgets.dart';

/// Renders a child at an integer *physical pixel* scale of a fixed virtual size,
/// with deterministic letterboxing.
///
/// This is the Flutter-side implementation of the "pixel-perfect" viewport
/// rules from `docs/plan.md`:
/// - virtual size is fixed (e.g., 480×270)
/// - scale is an integer in physical pixels (never fractional)
/// - remaining space is letterboxed with a solid color
///
/// Use [alignment] to control where letterboxing appears (e.g.
/// `Alignment.center` for centered letterbox, `Alignment.bottomLeft` to keep
/// the bottom-left edge pinned).
///
/// Note: this only guarantees correct sizing/letterboxing. The Flame side
/// still needs a fixed-resolution viewport/camera setup to ensure world units
/// map to virtual pixels (handled in later milestones).
class PixelPerfectViewport extends StatelessWidget {
  const PixelPerfectViewport({
    super.key,
    required this.virtualWidth,
    required this.virtualHeight,
    required this.child,
    this.letterboxColor = const Color(0xFF000000),
    this.alignment = Alignment.center,
  });

  final int virtualWidth;
  final int virtualHeight;
  final Widget child;
  final Color letterboxColor;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return child;
        }

        final screenPxW = constraints.maxWidth * devicePixelRatio;
        final screenPxH = constraints.maxHeight * devicePixelRatio;

        final scale = max(1, _computeLetterboxScale(screenPxW, screenPxH));

        final renderLogicalW = (virtualWidth * scale) / devicePixelRatio;
        final renderLogicalH = (virtualHeight * scale) / devicePixelRatio;

        final sizedChild = SizedBox(
          width: renderLogicalW,
          height: renderLogicalH,
          child: child,
        );

        return ColoredBox(
          color: letterboxColor,
          child: ClipRect(
            child: SizedBox.expand(
              child: Align(alignment: alignment, child: sizedChild),
            ),
          ),
        );
      },
    );
  }

  int _computeLetterboxScale(double screenPxW, double screenPxH) {
    final scaleW = screenPxW / virtualWidth;
    final scaleH = screenPxH / virtualHeight;
    return min(scaleW.floor(), scaleH.floor());
  }
}
