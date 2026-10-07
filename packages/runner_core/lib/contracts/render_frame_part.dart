import 'render_frame_rect.dart';
import '../util/vec2.dart';

/// One source region drawn within a logical animation frame, in image pixels.
/// Rotation is around the destination's top-center, before uniform actor scale.
final class RenderFramePart {
  const RenderFramePart({
    required this.source,
    required this.position,
    required this.size,
    this.rotationRadians = 0,
  });
  final RenderFrameRect source;
  final Vec2 position;
  final Vec2 size;
  final double rotationRadians;
}
