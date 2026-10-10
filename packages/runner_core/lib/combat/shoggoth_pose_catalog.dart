import '../snapshots/enums.dart';
import '../util/vec2.dart';
import 'combat_combo.dart';
import 'combat_geometry.dart';

/// Damage geometry in world units at Shoggoth's native 1.0x art scale.
abstract final class ShoggothPoseCatalog {
  /// Hand-tip center (44, 79) minus actor pivot (79, 65) in cast frame 8.
  /// Native art faces left; mirror X for a right-facing release at 1.0x scale.
  static const orbReleaseOffset = Vec2(-35, 14);

  static const shoggothSweep = CombatStrikeProfile(
    combo: CombatCombo(strikeStartFrames: [5, 7]),
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 11, activeStart: 5, activeEnd: 8),
    frames: [
      [],
      [],
      [],
      [],
      [],
      [CombatCapsule(-45.33, -13.33, -42.67, 20, 4.67)],
      [CombatCapsule(26.67, 13.33, 16, 38.67, 4.67)],
      [
        CombatCapsule(-46.67, -14.67, -42.67, 17.33, 4.67),
        CombatCapsule(21.33, 12, 28, 20, 4),
      ],
      [],
      [],
      [],
    ],
  );
  static const shoggothSpin = CombatStrikeProfile(
    combo: CombatCombo(strikeStartFrames: [3, 6]),
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 12, activeStart: 3, activeEnd: 9),
    frames: [
      [],
      [],
      [],
      [
        CombatCapsule(-16.67, -3.33, 16.67, -3.33, 8),
        CombatCapsule(-56, 5.33, -16, 14.67, 4.67),
      ],
      [
        CombatCapsule(-16.67, -3.33, 16.67, -3.33, 8),
        CombatCapsule(-69.33, -6, -73.33, 4, 3.33),
        CombatCapsule(-73.33, 4, -66, 10.67, 3.33),
        CombatCapsule(-66, 10.67, -44.67, 16, 3.33),
      ],
      [
        CombatCapsule(-16.67, -3.33, 16.67, -3.33, 8),
        CombatCapsule(-66.67, -8, -48, -12.67, 2),
      ],
      [
        CombatCapsule(-16.67, -3.33, 16.67, -3.33, 8),
        CombatCapsule(42.67, -4, 60, 1.33, 3.33),
        CombatCapsule(60, 1.33, 54.67, 12, 4),
        CombatCapsule(54.67, 12, 42.67, 15.33, 3.33),
      ],
      [
        CombatCapsule(-16.67, -3.33, 16.67, -3.33, 8),
        CombatCapsule(-10, 17.33, 22.67, 14.67, 4),
        CombatCapsule(22.67, 14.67, 44.67, 6, 4.67),
      ],
      [CombatCapsule(-13.33, -9.33, 13.33, -9.33, 10)],
      [],
      [],
      [],
    ],
  );

  /// Actor art phases share the committed action clock used by damage.
  static ActionFramePolicy? timingFor(String abilityId) => switch (abilityId) {
    'shoggoth.tentacle_sweep' => ShoggothPoseCatalog.shoggothSweep.timing,
    'shoggoth.spinning_charge' ||
    'shoggoth.return_charge' => ShoggothPoseCatalog.shoggothSpin.timing,
    'shoggoth.orb' => const ActionFramePolicy(
      frameCount: 11,
      activeStart: 8,
      activeEnd: 9,
    ),
    'shoggoth.summon' || 'shoggoth.summon_swarm' => const ActionFramePolicy(
      frameCount: 9,
      activeStart: 7,
      activeEnd: 8,
    ),
    _ => null,
  };
}
