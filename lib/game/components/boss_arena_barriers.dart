import 'dart:ui';

import 'package:flame/components.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';

/// Read-only boundary cues; confinement is solved by Core terrain motion.
class BossArenaBarriers extends Component {
  BossArenaBarriers() : super(priority: 50);
  BossArenaSnapshot? arena;
  final Paint _glow = Paint()
    ..color = const Color(0x447D3FC3)
    ..strokeWidth = 8;
  final Paint _edge = Paint()
    ..color = const Color(0xCCA779DA)
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    final state = arena;
    if (state == null) return;
    for (final x in [state.minX, state.maxX]) {
      canvas.drawLine(Offset(x, 0), Offset(x, 270), _glow);
      canvas.drawLine(Offset(x, 0), Offset(x, 270), _edge);
    }
  }
}
