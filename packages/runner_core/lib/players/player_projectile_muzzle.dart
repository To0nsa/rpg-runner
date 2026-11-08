import 'dart:math' as math;

import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';

/// Weapon-tip offsets in world units relative to the player's sprite pivot,
/// authored facing right at the firing phase. Running has eight body poses;
/// aim changes projectile velocity, never the attachment's position.
class PlayerProjectileMuzzle {
  const PlayerProjectileMuzzle({
    required this.standing,
    required this.airborne,
    required this.running,
  }) : assert(running.length == 8);

  final Vec2 standing;
  final Vec2 airborne;
  final List<Vec2> running;

  /// Samples the release posture without mirroring. The caller mirrors x with
  /// the visible facing; all pellets from a release share this offset.
  Vec2 offset({
    required RenderAnimSetDefinition renderAnim,
    required bool grounded,
    required double velocityX,
    required double minMoveSpeed,
    required int currentTick,
    required int tickHz,
  }) => switch (playerRangedAnimKey(
    renderAnim: renderAnim,
    grounded: grounded,
    velocityX: velocityX,
    minMoveSpeed: minMoveSpeed,
  )) {
    AnimKey.rangedAir => airborne,
    AnimKey.rangedRun =>
      running[playerRangedRunFrame(
        renderAnim: renderAnim,
        currentTick: currentTick,
        tickHz: tickHz,
      )],
    _ => standing,
  };
}

/// Shared posture selection for the visible firing art and its weapon tip.
AnimKey playerRangedAnimKey({
  required RenderAnimSetDefinition renderAnim,
  required bool grounded,
  required double velocityX,
  required double minMoveSpeed,
}) {
  if (!grounded && renderAnim.sourcesByKey.containsKey(AnimKey.rangedAir)) {
    return AnimKey.rangedAir;
  }
  if (velocityX.abs() > minMoveSpeed &&
      renderAnim.sourcesByKey.containsKey(AnimKey.rangedRun)) {
    return AnimKey.rangedRun;
  }
  return AnimKey.ranged;
}

/// Samples the eight locomotion poses inside each running firing phase using
/// the same quantized strip clock as AnimSystem and the renderer.
int playerRangedRunFrame({
  required RenderAnimSetDefinition renderAnim,
  required int currentTick,
  required int tickHz,
}) {
  final step = math.max(
    1,
    ((renderAnim.stepTimeSecondsByKey[AnimKey.rangedRun] ?? .1) * tickHz)
        .round(),
  );
  return (currentTick ~/ step) % 8;
}
