import 'package:flutter/widgets.dart';

/// An immersive landscape display, measured in logical pixels (DevTools CSS px).
/// Pixel density controls the game's pixel-perfect viewport, independently of
/// the editor monitor and the caller's fixed physical preview scale.
@immutable
class RunnerPlaytestDisplay {
  const RunnerPlaytestDisplay({
    required this.width,
    required this.height,
    required this.devicePixelRatio,
  }) : assert(width >= minDimension && width <= maxDimension),
       assert(height >= minDimension && height <= maxDimension),
       assert(width >= height),
       assert(
         devicePixelRatio >= minPixelRatio && devicePixelRatio <= maxPixelRatio,
       );

  // Bounded preview sizes keep custom layouts usable without huge render targets.
  static const minDimension = 240;
  static const maxDimension = 4096;
  static const minPixelRatio = 1.0;
  static const maxPixelRatio = 4.0;

  final int width;
  final int height;
  final double devicePixelRatio;
  Size get size => Size(width.toDouble(), height.toDouble());

  @override
  bool operator ==(Object other) =>
      other is RunnerPlaytestDisplay &&
      width == other.width &&
      height == other.height &&
      devicePixelRatio == other.devicePixelRatio;

  @override
  int get hashCode => Object.hash(width, height, devicePixelRatio);
}
