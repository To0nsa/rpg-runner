import '../snapshots/enums.dart';
import 'combat_geometry.dart';

/// Ancient God damage poses in world units at the shared 1.5x art scale.
abstract final class AncientGodPoseCatalog {
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
  static const minionBite = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 6, activeStart: 3, activeEnd: 5),
    frames: [
      [],
      [],
      [],
      [CombatCapsule(-8, -4, -23, -4, 4)],
      [CombatCapsule(-8, -4, -23, -4, 4)],
      [],
    ],
  );
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
}
