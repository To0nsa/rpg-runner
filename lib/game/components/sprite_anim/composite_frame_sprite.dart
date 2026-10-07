import 'dart:ui';

import 'package:flame/components.dart';
import 'package:runner_core/contracts/render_frame_part.dart';

/// Draws catalog-owned effect parts directly from the run-owned source image.
/// No derived image cache or rendering timer is introduced.
class CompositeFrameSprite extends Sprite {
  CompositeFrameSprite(
    super.image, {
    required Vector2 frameSize,
    required this.parts,
  }) : super(srcSize: frameSize);
  final List<RenderFramePart> parts;

  @override
  void render(
    Canvas canvas, {
    Vector2? position,
    Vector2? size,
    Anchor anchor = Anchor.topLeft,
    Paint? overridePaint,
    double? bleed,
  }) {
    final actual = size ?? srcSize;
    final x = (position?.x ?? 0) - anchor.x * actual.x;
    final y = (position?.y ?? 0) - anchor.y * actual.y;
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(actual.x / srcSize.x, actual.y / srcSize.y);
    for (final part in parts) {
      final source = part.source;
      canvas.save();
      canvas.translate(part.position.x + part.size.x / 2, part.position.y);
      canvas.rotate(part.rotationRadians);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(
          source.x.toDouble(),
          source.y.toDouble(),
          source.width.toDouble(),
          source.height.toDouble(),
        ),
        Rect.fromLTWH(-part.size.x / 2, 0, part.size.x, part.size.y),
        overridePaint ?? paint,
      );
      canvas.restore();
    }
    canvas.restore();
  }
}
