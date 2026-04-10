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

  /// Authoring layer index for ordering.
  final int zIndex;
}
