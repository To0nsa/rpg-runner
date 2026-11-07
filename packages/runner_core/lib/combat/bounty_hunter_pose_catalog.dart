import '../snapshots/enums.dart';
import 'combat_combo.dart';
import 'combat_geometry.dart';

/// Blade geometry relative to the aligned (34, 46) sprite pivot. Separate
/// strike windows let each visible swing land once without widening the body.
abstract final class BountyHunterPoseCatalog {
  static const _high = [
    CombatCapsule(8, -12, 31, -18, 4),
    CombatCapsule(31, -18, 39, 0, 4),
  ];
  static const _low = [CombatCapsule(9, 4, 35, 10, 4)];
  static const _thrust = [CombatCapsule(9, -2, 42, -2, 3)];
  static const quick = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 7, activeStart: 3, activeEnd: 5),
    frames: [[], [], [], _high, _low, [], []],
  );
  static const twin = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 14, activeStart: 3, activeEnd: 10),
    combo: CombatCombo(strikeStartFrames: [3, 8]),
    frames: [[], [], [], _high, _low, [], [], [], _high, _low, [], [], [], []],
  );
  static const triple = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 13, activeStart: 3, activeEnd: 12),
    combo: CombatCombo(strikeStartFrames: [3, 6, 10]),
    frames: [
      [],
      [],
      [],
      _low,
      _low,
      [],
      _high,
      _high,
      [],
      [],
      _thrust,
      _thrust,
      [],
    ],
  );
  static const lunge = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 9, activeStart: 5, activeEnd: 8),
    frames: [[], [], [], [], [], _thrust, _thrust, _thrust, []],
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
    'bounty_hunter.threefold_cut' => triple.timing,
    'bounty_hunter.lunge_slash' => lunge.timing,
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
      -5,
      9,
      6,
      9,
      7,
    ),
    AnimKey.slide => const CombatCapsule(-6, 10, 7, 10, 6),
    AnimKey.dash || AnimKey.lunge => const CombatCapsule(-3, -2, 5, 9, 7),
    AnimKey.doubleJump => const CombatCapsule(-3, 0, 3, 6, 8),
    AnimKey.jump ||
    AnimKey.fall ||
    AnimKey.rangedAir => const CombatCapsule(0, -8, 0, 6, 7),
    _ => null,
  };
}
