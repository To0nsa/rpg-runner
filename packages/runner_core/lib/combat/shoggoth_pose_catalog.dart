import '../snapshots/enums.dart';
import 'combat_geometry.dart';

/// Damage geometry in world units at Shoggoth's 1.5x art scale.
abstract final class ShoggothPoseCatalog {
  static const shoggothSweep = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 11, activeStart: 5, activeEnd: 8),
    frames: [
      [],
      [],
      [],
      [],
      [],
      [CombatCapsule(-68, -20, -64, 30, 7)],
      [CombatCapsule(40, 20, 24, 58, 7)],
      [CombatCapsule(-70, -22, -64, 26, 7), CombatCapsule(32, 18, 42, 30, 6)],
      [],
      [],
      [],
    ],
  );
  static const shoggothSpin = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 12, activeStart: 3, activeEnd: 9),
    frames: [
      [],
      [],
      [],
      [CombatCapsule(-25, -5, 25, -5, 12), CombatCapsule(-84, 8, -24, 22, 7)],
      [CombatCapsule(-25, -5, 25, -5, 12), CombatCapsule(-80, -7, -56, 14, 7)],
      [
        CombatCapsule(-25, -5, 25, -5, 12),
        CombatCapsule(-86, -20, -40, -20, 5),
      ],
      [CombatCapsule(-25, -5, 25, -5, 12)],
      [CombatCapsule(-25, -5, 25, -5, 12)],
      [CombatCapsule(-20, -14, 20, -14, 15)],
      [],
      [],
      [],
    ],
  );

  /// Actor art phases share the committed action clock used by damage.
  static ActionFramePolicy? timingFor(String abilityId) => switch (abilityId) {
    'shoggoth.tentacle_sweep' => ShoggothPoseCatalog.shoggothSweep.timing,
    'shoggoth.spinning_charge' => ShoggothPoseCatalog.shoggothSpin.timing,
    'shoggoth.orb' => const ActionFramePolicy(
      frameCount: 11,
      activeStart: 8,
      activeEnd: 9,
    ),
    'shoggoth.summon' => const ActionFramePolicy(
      frameCount: 9,
      activeStart: 7,
      activeEnd: 8,
    ),
    _ => null,
  };
}
