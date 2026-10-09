import 'dart:ui';

import 'package:flame/components.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';

/// World-space destination marks live exactly as long as Core publishes them.
class TeleportDestinationCues extends Component {
  TeleportDestinationCues() : super(priority: 49);
  Iterable<EntityRenderSnapshot> entities = const [];
  final _fill = Paint()..color = const Color(0x337B4ACB);
  final _edge = Paint()
    ..color = const Color(0xDDBA8CFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void render(Canvas canvas) {
    for (final entity in entities) {
      final destination = entity.teleportDestination;
      if (destination == null) continue;
      final halfHeight = (entity.size?.y ?? 54) / 2;
      final center = Offset(destination.x, destination.y);
      final silhouette = Rect.fromCenter(
        center: center,
        width: 22,
        height: halfHeight * 2,
      );
      canvas.drawOval(silhouette, _fill);
      canvas.drawOval(silhouette, _edge);
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, halfHeight),
          width: 32,
          height: 8,
        ),
        _edge,
      );
    }
  }
}
