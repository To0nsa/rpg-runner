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
      activeStart: 6,
      activeEnd: 36,
    ),
    _ => null,
  };
}
