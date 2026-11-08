import '../players/characters/bounty_hunter_geometry.dart';
import '../snapshots/enums.dart';
import 'combat_combo.dart';
import 'combat_geometry.dart';

/// Source poses converted to world units around the support-aligned pivot. Separate
/// strike windows let each visible swing land once without widening the body.
abstract final class BountyHunterPoseCatalog {
  static const _scale = bountyHunterWorldScale;
  static const _shiftY = bountyHunterPoseOriginShiftY;
  static const _high = [
    CombatCapsule(
      8 * _scale,
      (-12 + _shiftY) * _scale,
      31 * _scale,
      (-18 + _shiftY) * _scale,
      4 * _scale,
    ),
    CombatCapsule(
      31 * _scale,
      (-18 + _shiftY) * _scale,
      39 * _scale,
      (0 + _shiftY) * _scale,
      4 * _scale,
    ),
  ];
  static const _low = [
    CombatCapsule(
      9 * _scale,
      (4 + _shiftY) * _scale,
      35 * _scale,
      (10 + _shiftY) * _scale,
      4 * _scale,
    ),
  ];
  static const _thrust = [
    CombatCapsule(
      9 * _scale,
      (-2 + _shiftY) * _scale,
      42 * _scale,
      (-2 + _shiftY) * _scale,
      3 * _scale,
    ),
  ];
  static const quick = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 7, activeStart: 3, activeEnd: 5),
    frames: [[], [], [], _high, _low, [], []],
  );
  static const twin = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 8, activeStart: 3, activeEnd: 7),
    combo: CombatCombo(strikeStartFrames: [3, 6]),
    frames: [[], [], [], _low, _low, [], _high, []],
  );
  static const lunge = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 5, activeStart: 1, activeEnd: 3),
    frames: [[], _thrust, _thrust, [], []],
  );
  static const shot = ActionFramePolicy(
    frameCount: 3,
    activeStart: 1,
    activeEnd: 2,
  );
  static const drop = ActionFramePolicy(
    frameCount: 10,
    activeStart: 6,
    activeEnd: 7,
  );

  static ActionFramePolicy? timingFor(String id) => switch (id) {
    'bounty_hunter.quick_cut' => quick.timing,
    'bounty_hunter.twin_cut' => twin.timing,
    'bounty_hunter.lunge_slash' => lunge.timing,
    'bounty_hunter.blink_dash' => const ActionFramePolicy(
      frameCount: 10,
      activeStart: 4,
      activeEnd: 5,
    ),
    'bounty_hunter.blast_bomb' ||
    'bounty_hunter.shrapnel_bomb' ||
    'bounty_hunter.fire_bomb' ||
    'bounty_hunter.concussion_bomb' => drop,
    'bounty_hunter.snap_shot' ||
    'bounty_hunter.quick_shot' ||
    'bounty_hunter.piercing_shot' ||
    'bounty_hunter.scatter_shot' ||
    'bounty_hunter.charged_shot' => shot,
    _ => null,
  };

  /// Low poses affect vulnerability only; the terrain capsule stays immutable.
  static CombatCapsule? hurtbox(AnimKey key, int frame) => switch (key) {
    AnimKey.roll when frame > 0 && frame < 5 => const CombatCapsule(
      -5 * _scale,
      (9 + _shiftY) * _scale,
      6 * _scale,
      (9 + _shiftY) * _scale,
      7 * _scale,
    ),
    AnimKey.slide => const CombatCapsule(
      -6 * _scale,
      (10 + _shiftY) * _scale,
      7 * _scale,
      (10 + _shiftY) * _scale,
      6 * _scale,
    ),
    AnimKey.dash || AnimKey.lunge => const CombatCapsule(
      -3 * _scale,
      (-2 + _shiftY) * _scale,
      5 * _scale,
      (9 + _shiftY) * _scale,
      7 * _scale,
    ),
    AnimKey.doubleJump => const CombatCapsule(
      -3 * _scale,
      (0 + _shiftY) * _scale,
      3 * _scale,
      (6 + _shiftY) * _scale,
      8 * _scale,
    ),
    AnimKey.jump || AnimKey.fall || AnimKey.rangedAir => const CombatCapsule(
      0 * _scale,
      (-8 + _shiftY) * _scale,
      0 * _scale,
      (6 + _shiftY) * _scale,
      7 * _scale,
    ),
    _ => null,
  };
}
