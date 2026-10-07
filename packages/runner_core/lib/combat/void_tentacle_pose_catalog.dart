import '../snapshots/enums.dart';
import 'combat_geometry.dart';

/// Damage geometry in world units at VoidTentacle's 1.5x art scale.
abstract final class VoidTentaclePoseCatalog {
  static const tentacleLash = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 7, activeStart: 3, activeEnd: 6),
    frames: [
      [],
      [],
      [],
      [CombatCapsule(-62, -2, -42, -22, 6)],
      [CombatCapsule(-68, 12, -46, -16, 7)],
      [CombatCapsule(-68, 0, -22, -8, 7)],
      [],
    ],
  );

  /// Actor art phases share the committed action clock used by damage.
  static ActionFramePolicy? timingFor(String abilityId) => switch (abilityId) {
    'void_tentacle.lash' => VoidTentaclePoseCatalog.tentacleLash.timing,
    _ => null,
  };
}
