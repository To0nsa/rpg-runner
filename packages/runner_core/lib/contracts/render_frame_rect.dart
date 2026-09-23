/// An explicit source rectangle in image pixels, independent of sheet layout.
final class RenderFrameRect {
  const RenderFrameRect(this.x, this.y, this.width, this.height)
    : assert(x >= 0 && y >= 0 && width > 0 && height > 0);

  final int x;
  final int y;
  final int width;
  final int height;
}
