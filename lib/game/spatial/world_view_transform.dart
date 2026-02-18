/// Stateless world<->view transform helpers.
///
/// Current runner rendering assumes an axis-aligned camera without rotation.
/// These helpers make that mapping explicit and reusable.
library;

class WorldViewTransform {
  const WorldViewTransform({
    required this.cameraCenterX,
    required this.cameraCenterY,
    required this.viewWidth,
    required this.viewHeight,
  }) : assert(viewWidth > 0),
       assert(viewHeight > 0);

  /// Camera center in world coordinates.
  final double cameraCenterX;
  final double cameraCenterY;

  /// Viewport size in world/view units.
  final double viewWidth;
  final double viewHeight;

  /// Left edge of the viewport in world coordinates.
  double get viewLeftX => cameraCenterX - viewWidth * 0.5;

  /// Right edge of the viewport in world coordinates.
  double get viewRightX => cameraCenterX + viewWidth * 0.5;

  /// Top edge of the viewport in world coordinates.
  double get viewTopY => cameraCenterY - viewHeight * 0.5;

  /// Bottom edge of the viewport in world coordinates.
  double get viewBottomY => cameraCenterY + viewHeight * 0.5;

  /// Converts a world X coordinate to view-space X.
  double worldToViewX(double worldX) => worldX - viewLeftX;

  /// Converts a world Y coordinate to view-space Y.
  double worldToViewY(double worldY) => worldY - viewTopY;

  /// Converts a view-space X coordinate to world X.
  double viewToWorldX(double viewX) => viewLeftX + viewX;

  /// Converts a view-space Y coordinate to world Y.
  double viewToWorldY(double viewY) => viewTopY + viewY;
}
