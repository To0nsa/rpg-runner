/// Whole-pixel rectangle relative to a trap's sprite anchor.
final class TrapRect {
  const TrapRect(this.offsetX, this.offsetY, this.width, this.height);

  final int offsetX;
  final int offsetY;
  final int width;
  final int height;
  int get right => offsetX + width;
  int get bottom => offsetY + height;

  TrapRect mirrored() => TrapRect(-right, offsetY, width, height);

  Map<String, Object> toJson() => {
    'offsetX': offsetX,
    'offsetY': offsetY,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is TrapRect &&
      offsetX == other.offsetX &&
      offsetY == other.offsetY &&
      width == other.width &&
      height == other.height;
  @override
  int get hashCode => Object.hash(offsetX, offsetY, width, height);
}

/// Catalog-owned damaging capsule relative to the sprite anchor, in pixels.
/// The same shape feeds combat narrow phase and the editor's read-only overlay.
final class TrapHitCapsule {
  const TrapHitCapsule(this.ax, this.ay, this.bx, this.by, this.radius);
  final double ax;
  final double ay;
  final double bx;
  final double by;
  final double radius;
}
