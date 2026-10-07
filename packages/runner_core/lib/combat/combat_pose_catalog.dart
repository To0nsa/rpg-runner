import '../snapshots/enums.dart';
import 'combat_geometry.dart';
import 'voidborn_goddess_pose_catalog.dart';
import 'shoggoth_pose_catalog.dart';
import 'voidcaller_pose_catalog.dart';
import 'shoggoth_minion_pose_catalog.dart';
import 'void_tentacle_pose_catalog.dart';

/// Reviewed source-art damage poses at runtime presentation scale. Coordinates
/// are relative to catalog sprite anchors; blade arcs use multiple thin capsules
/// instead of enclosing the actor and weapon in one oversized damage volume.
abstract final class CombatPoseCatalog {
  static const eloiseStrike = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 6, activeStart: 2, activeEnd: 4),
    frames: [
      [],
      [],
      [CombatCapsule(8, 4, 32, -12, 4), CombatCapsule(18, -5, 33, -15, 3)],
      [CombatCapsule(17, -16, 32, -10, 4), CombatCapsule(32, -10, 26, 2, 4)],
      [],
      [],
    ],
  );
  static const eloiseBackStrike = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 5, activeStart: 2, activeEnd: 4),
    frames: [
      [],
      [],
      [CombatCapsule(8, -10, 27, -10, 3)],
      [
        CombatCapsule(15, -5, 31, 0, 3),
        CombatCapsule(31, 0, 24, 8, 3),
        CombatCapsule(24, 8, 3, 10, 3),
      ],
      [],
    ],
  );
  static const warriorSlash = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 4, activeStart: 2, activeEnd: 3),
    frames: [
      [],
      [],
      [
        CombatCapsule(14, -38, 53, -35, 6),
        CombatCapsule(53, -35, 77, -17, 7),
        CombatCapsule(77, -17, 55, 3, 7),
      ],
      [],
    ],
  );
  static const huntressStab = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 5, activeStart: 3, activeEnd: 4),
    frames: [
      [],
      [],
      [],
      [
        CombatCapsule(14, -60, 48, -55, 5),
        CombatCapsule(48, -55, 68, -30, 7),
        CombatCapsule(68, -30, 47, -5, 6),
        CombatCapsule(47, -5, 27, 16, 7),
      ],
      [],
    ],
  );
  static const huntressSlash = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 5, activeStart: 3, activeEnd: 4),
    frames: [
      [],
      [],
      [],
      [
        CombatCapsule(0, -59, 35, -60, 6),
        CombatCapsule(35, -60, 66, -40, 7),
        CombatCapsule(66, -40, 61, -12, 7),
        CombatCapsule(61, -12, 45, 12, 7),
      ],
      [],
    ],
  );
  static const grojibStrike = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 8, activeStart: 4, activeEnd: 6),
    frames: [
      [],
      [],
      [],
      [],
      [CombatCapsule(-42, -15, -66, 3, 7), CombatCapsule(-66, 3, -47, 24, 8)],
      [CombatCapsule(-62, 19, -35, 33, 7)],
      [],
      [],
    ],
  );
  static const grojibStrike2 = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 12, activeStart: 4, activeEnd: 7),
    frames: [
      [],
      [],
      [],
      [],
      [CombatCapsule(-43, -28, -67, 14, 9)],
      [CombatCapsule(-70, 31, -48, 33, 8)],
      [CombatCapsule(-70, 31, -48, 33, 7)],
      [],
      [],
      [],
      [],
      [],
    ],
  );
  static const hashashStrike = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 13, activeStart: 8, activeEnd: 10),
    frames: [
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      [],
      [CombatCapsule(-21, -11, -36, 7, 5)],
      [CombatCapsule(-33, 7, -16, 16, 5)],
      [],
      [],
      [],
    ],
  );
  static const hashashAmbush = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 12, activeStart: 6, activeEnd: 9),
    frames: [
      [],
      [],
      [],
      [],
      [],
      [],
      [CombatCapsule(-18, -13, -28, 7, 5)],
      [CombatCapsule(-29, -12, -34, 12, 5)],
      [CombatCapsule(-31, 2, -14, 14, 5)],
      [],
      [],
      [],
    ],
  );
  static const unocoStrike = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 8, activeStart: 6, activeEnd: 7),
    frames: [
      [],
      [],
      [],
      [],
      [],
      [],
      [CombatCapsule(-5, 5, -10, 10, 3)],
      [],
    ],
  );

  static const derfTentacle = CombatStrikeProfile(
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 7, activeStart: 3, activeEnd: 5),
    frames: [
      [],
      [],
      [],
      [CombatCapsule(-26, -9, -102, -9, 3)],
      [CombatCapsule(-27, -9, -104, -9, 3)],
      [],
      [],
    ],
  );
  static const bringerScythe = CombatStrikeProfile(
    // World-unit blade poses at 1.5x source scale, matching the boss sprite.
    artFacing: Facing.left,
    timing: ActionFramePolicy(frameCount: 10, activeStart: 4, activeEnd: 7),
    frames: [
      [],
      [],
      [],
      [],
      [
        CombatCapsule(-18, -30, -97.5, -40.5, 9),
        CombatCapsule(-97.5, -40.5, -129, -10.5, 10.5),
      ],
      [
        CombatCapsule(-27, -36, -114, -25.5, 10.5),
        CombatCapsule(-114, -25.5, -120, 12, 10.5),
      ],
      [CombatCapsule(-36, -27, -103.5, 9, 9)],
      [],
      [],
      [],
    ],
  );
  static const bringerPillar = CombatStrikeProfile(
    // 1.5x source poses translated from the old Y=56 pivot to the bottom Y=93.
    timing: ActionFramePolicy(frameCount: 16, activeStart: 6, activeEnd: 12),
    frames: [
      [],
      [],
      [],
      [],
      [],
      [],
      [CombatCapsule(0, -85.5, 0, -19.5, 15)],
      [CombatCapsule(0, -85.5, 0, -19.5, 15)],
      [CombatCapsule(0, -85.5, 0, -19.5, 15)],
      [CombatCapsule(0, -85.5, 0, -19.5, 15)],
      [CombatCapsule(0, -85.5, 0, -19.5, 15)],
      [CombatCapsule(0, -85.5, 0, -19.5, 15)],
      [],
      [],
      [],
      [],
    ],
  );
  static const bringerCast = ActionFramePolicy(
    frameCount: 9,
    activeStart: 5,
    activeEnd: 6,
  );
  static const fireExplosion = CombatStrikeProfile(
    timing: ActionFramePolicy(frameCount: 16, activeStart: 2, activeEnd: 4),
    frames: [
      [],
      [],
      [CombatCapsule(0, -4, 0, 5, 19)],
      [CombatCapsule(0, -5, 0, 5, 23)],
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
      [],
      [],
    ],
  );
  static const ranged = ActionFramePolicy(
    frameCount: 5,
    activeStart: 2,
    activeEnd: 3,
  );
  static const shield = ActionFramePolicy(
    frameCount: 7,
    activeStart: 3,
    activeEnd: 4,
    holdActivePose: true,
  );
  static const spearThrow = ActionFramePolicy(
    frameCount: 7,
    activeStart: 6,
    activeEnd: 7,
  );
  static const arrowShot = ActionFramePolicy(
    frameCount: 6,
    activeStart: 2,
    activeEnd: 3,
  );
  static const unocoCast = ActionFramePolicy(
    frameCount: 8,
    activeStart: 6,
    activeEnd: 7,
  );
  static const derfCast = ActionFramePolicy(
    frameCount: 10,
    activeStart: 4,
    activeEnd: 5,
  );

  static ActionFramePolicy? timingFor(String abilityId, AnimKey anim) =>
      switch (abilityId) {
        'eloise.bloodletter_slash' ||
        'eloise.bloodletter_cleave' ||
        'eloise.seeker_slash' =>
          (anim == AnimKey.backStrike ? eloiseBackStrike : eloiseStrike).timing,
        'eloise.snap_shot' ||
        'eloise.quick_shot' ||
        'eloise.skewer_shot' ||
        'eloise.overcharge_shot' => ranged,
        'eloise.shield_block' || 'eloise.aegis_riposte' => shield,
        'npc_warrior.slash' => warriorSlash.timing,
        'npc_huntress.stab' => huntressStab.timing,
        'npc_huntress.slash' => huntressSlash.timing,
        'npc_huntress.throw_spear' => spearThrow,
        'npc_huntress2.shoot_arrow' => arrowShot,
        'grojib.strike' => grojibStrike.timing,
        'grojib.strike2' => grojibStrike2.timing,
        'hashash.strike' => hashashStrike.timing,
        'hashash.ambush' => hashashAmbush.timing,
        'unoco.strike' => unocoStrike.timing,
        'unoco.fire_bolt_cast' => unocoCast,
        'derf.fire_explosion' => derfCast,
        'bringer.scythe_sweep' => bringerScythe.timing,
        'bringer.death_pillar' => bringerCast,
        _ =>
          VoidbornGoddessPoseCatalog.timingFor(abilityId) ??
              ShoggothPoseCatalog.timingFor(abilityId) ??
              VoidcallerPoseCatalog.timingFor(abilityId) ??
              ShoggothMinionPoseCatalog.timingFor(abilityId) ??
              VoidTentaclePoseCatalog.timingFor(abilityId),
      };
}
