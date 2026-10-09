import '../snapshots/enums.dart';
import 'combat_combo.dart';
import 'combat_geometry.dart';

/// World-unit geometry: claws fit the 1.2x actor, hands the 1.5x effect art.
abstract final class VoidbornGoddessPoseCatalog {
  static const goddessClaws = CombatStrikeProfile(
    combo: CombatCombo(strikeStartFrames: [4, 7, 12, 15]),
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 19, activeStart: 4, activeEnd: 17),
    frames: [
      [],
      [],
      [],
      [],
      [CombatCapsule(-17.6, -9.6, -56.8, -13.6, 4.8)],
      [CombatCapsule(-17.6, -9.6, -56.8, -13.6, 4.8)],
      [CombatCapsule(-17.6, -9.6, -56.8, -13.6, 4.8)],
      [CombatCapsule(-20.8, -4, -54.4, 4.8, 4.8)],
      [CombatCapsule(-20.8, -4, -54.4, 4.8, 4.8)],
      [CombatCapsule(-20.8, -4, -54.4, 4.8, 4.8)],
      [],
      [],
      [CombatCapsule(-17.6, -12.8, -48, -20, 4.8)],
      [CombatCapsule(-17.6, -12.8, -48, -20, 4.8)],
      [],
      [CombatCapsule(-19.2, -6.4, -49.6, 9.6, 4.8)],
      [CombatCapsule(-19.2, -6.4, -49.6, 9.6, 4.8)],
      [],
      [],
    ],
  );

  /// Palm and finger silhouettes for each slap pose, excluding detached motes
  /// and impact streaks. Source pixels use pivot (69, 92) at 1.5x effect scale.
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
      [
        CombatCapsule(-13.5, -42, -9, -19.5, 13.5),
        CombatCapsule(-13.5, -15, 12, -7.5, 7.5),
        CombatCapsule(-21, -7.5, 9, -7.5, 7.5),
        CombatCapsule(-27, -33, -13.5, -27, 6),
      ],
      [
        CombatCapsule(-13.5, -46.5, -13.5, -28.5, 10.5),
        CombatCapsule(-12, -25.5, -6, -12, 13.5),
        CombatCapsule(-21, -6, 15, -6, 6),
        CombatCapsule(4.5, -18, 18, -7.5, 7.5),
      ],
      [
        CombatCapsule(-13.5, -57, -12, -24, 9),
        CombatCapsule(-16.5, -33, -9, -18, 13.5),
        CombatCapsule(-27, -36, -18, -34.5, 6),
        CombatCapsule(-21, -6, 19.5, -6, 6),
        CombatCapsule(4.5, -19.5, 19.5, -7.5, 7.5),
      ],
      [
        CombatCapsule(-13.5, -45, -7.5, -16.5, 12),
        CombatCapsule(-22.5, -6, 18, -6, 6),
        CombatCapsule(4.5, -19.5, 19.5, -7.5, 7.5),
      ],
      [
        CombatCapsule(-7.5, -33, -9, -16.5, 13.5),
        CombatCapsule(-18, -37.5, -12, -31.5, 7.5),
        CombatCapsule(-24, -6, 16.5, -6, 6),
        CombatCapsule(-22.5, -15, -18, -10.5, 7.5),
        CombatCapsule(-4.5, -12, 18, -6, 6),
      ],
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
      activeStart: 6,
      activeEnd: 36,
    ),
    _ => null,
  };
}
