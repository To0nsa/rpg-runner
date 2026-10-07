/// Renderer-facing snapshot for one authored static prefab visual sprite.
library;

class StaticPrefabSpriteSnapshot {
  const StaticPrefabSpriteSnapshot({
    required this.assetPath,
    required this.srcX,
    required this.srcY,
    required this.srcWidth,
    required this.srcHeight,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
    this.flipX = false,
    this.flipY = false,
    this.rotationDegrees = 0,
  });

  final String assetPath;
  final int srcX;
  final int srcY;
  final int srcWidth;
  final int srcHeight;

  /// World-space destination top-left.
  final double x;
  final double y;

  /// World-space destination size.
  final double width;
  final double height;

  /// Layer relative to the owning chunk's terrain: negative renders behind it;
  /// zero and positive render in front. This is not a Flame component priority.
  final int zIndex;
  final bool flipX;
  final bool flipY;

  /// Clockwise visual rotation in [0, 360) around this sprite's center.
  /// X/Y locate its unrotated destination rectangle at the rotated tile center.
  final double rotationDegrees;
}
