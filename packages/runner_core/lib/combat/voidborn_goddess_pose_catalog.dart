import '../snapshots/enums.dart';
import 'combat_geometry.dart';

/// Damage geometry in world units at VoidbornGoddess's 1.5x art scale.
abstract final class VoidbornGoddessPoseCatalog {
  static const goddessClaws = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 19, activeStart: 4, activeEnd: 17),
    frames: [
      [],
      [],
      [],
      [],
      [CombatCapsule(-22, -12, -71, -17, 6)],
      [CombatCapsule(-22, -12, -71, -17, 6)],
      [CombatCapsule(-22, -12, -71, -17, 6)],
      [CombatCapsule(-26, -5, -68, 6, 6)],
      [CombatCapsule(-26, -5, -68, 6, 6)],
      [CombatCapsule(-26, -5, -68, 6, 6)],
      [],
      [CombatCapsule(-22, -16, -60, -25, 6)],
      [CombatCapsule(-22, -16, -60, -25, 6)],
      [CombatCapsule(-22, -16, -60, -25, 6)],
      [],
      [CombatCapsule(-24, -8, -62, 12, 6)],
      [CombatCapsule(-24, -8, -62, 12, 6)],
      [],
      [],
    ],
  );
  static const goddessEruption = CombatStrikeProfile(
    artFacing: Facing.right,
    timing: ActionFramePolicy(frameCount: 17, activeStart: 10, activeEnd: 15),
    frames: [
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      [CombatCapsule(0, -5, 0, -10, 12)],
      [CombatCapsule(0, -5, 0, -10, 12)],
      [CombatCapsule(0, -10, 0, -38, 12)],
      [CombatCapsule(0, -10, 0, -38, 12)],
      [CombatCapsule(0, -10, 0, -38, 12)],
      [],
      [],
    ],
  );

  /// Actor art phases share the committed action clock used by damage.
  static ActionFramePolicy? timingFor(String abilityId) => switch (abilityId) {
    'goddess.claw_combo' => VoidbornGoddessPoseCatalog.goddessClaws.timing,
    'goddess.orb' => const ActionFramePolicy(
      frameCount: 11,
      activeStart: 8,
      activeEnd: 9,
    ),
    'goddess.eruption' => const ActionFramePolicy(
      frameCount: 36,
      activeStart: 26,
      activeEnd: 27,
    ),
    _ => null,
  };
}
