import '../snapshots/enums.dart';
import 'combat_geometry.dart';

/// Damage geometry in world units at Voidcaller's 1.5x art scale.
abstract final class VoidcallerPoseCatalog {
  static const voidVerticalBeam = CombatStrikeProfile(
    artFacing: Facing.right,
    timing: ActionFramePolicy(frameCount: 12, activeStart: 5, activeEnd: 10),
    frames: [
      [],
      [],
      [],
      [],
      [],
      [CombatCapsule(0, -180, 0, -12, 8)],
      [CombatCapsule(0, -180, 0, -12, 8)],
      [CombatCapsule(0, -180, 0, -12, 8)],
      [CombatCapsule(0, -180, 0, -12, 8)],
      [CombatCapsule(0, -180, 0, -12, 8)],
      [],
      [],
    ],
  );
  static const voidDiagonalBeam = CombatStrikeProfile(
    artFacing: Facing.right,
    timing: ActionFramePolicy(frameCount: 12, activeStart: 5, activeEnd: 10),
    frames: [
      [],
      [],
      [],
      [],
      [],
      [CombatCapsule(-90, -180, 0, -12, 8)],
      [CombatCapsule(-90, -180, 0, -12, 8)],
      [CombatCapsule(-90, -180, 0, -12, 8)],
      [CombatCapsule(-90, -180, 0, -12, 8)],
      [CombatCapsule(-90, -180, 0, -12, 8)],
      [],
      [],
    ],
  );

  /// Actor art phases share the committed action clock used by damage.
  static ActionFramePolicy? timingFor(String abilityId) => switch (abilityId) {
    'voidcaller.vertical_beam' => const ActionFramePolicy(
      frameCount: 17,
      activeStart: 10,
      activeEnd: 11,
    ),
    'voidcaller.diagonal_beam' => const ActionFramePolicy(
      frameCount: 17,
      activeStart: 10,
      activeEnd: 11,
    ),
    'voidcaller.claw' => const ActionFramePolicy(
      frameCount: 10,
      activeStart: 6,
      activeEnd: 7,
    ),
    'voidcaller.summon' => const ActionFramePolicy(
      frameCount: 17,
      activeStart: 10,
      activeEnd: 11,
    ),
    _ => null,
  };
}
