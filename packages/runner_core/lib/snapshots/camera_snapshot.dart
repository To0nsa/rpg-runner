/// Immutable camera data exported by Core for renderer/UI consumption.
///
/// This snapshot describes camera framing in world units and is the preferred
/// camera contract over legacy scalar fields.
class CameraSnapshot {
  const CameraSnapshot({
    required this.centerX,
    required this.centerY,
    required this.viewWidth,
    required this.viewHeight,
  }) : assert(viewWidth > 0),
       assert(viewHeight > 0);

  /// Camera center in world coordinates.
  final double centerX;
  final double centerY;

  /// Viewport dimensions in world units.
  final double viewWidth;
  final double viewHeight;

  double get left => centerX - viewWidth * 0.5;
  double get right => centerX + viewWidth * 0.5;
  double get top => centerY - viewHeight * 0.5;
  double get bottom => centerY + viewHeight * 0.5;
}
