import '../../abilities/ability_def.dart';
import '../../contracts/render_anim_set_definition.dart';
import '../../contracts/render_frame_part.dart';
import '../../contracts/render_frame_rect.dart';
import '../../ecs/stores/body_store.dart';
import '../../ecs/stores/combat/creature_tag_store.dart';
import '../../ecs/stores/combat/damage_resistance_store.dart';
import '../../ecs/stores/combat/equipped_loadout_store.dart';
import '../../ecs/stores/combat/status_immunity_store.dart';
import '../../combat/creature_tag.dart';
import '../../projectiles/projectile_id.dart';
import '../../snapshots/enums.dart';
import '../../spellBook/spell_book_id.dart';
import '../../weapons/weapon_id.dart';
import '../../util/vec2.dart';
import '../player_catalog.dart';
import '../player_character_definition.dart';
import '../player_tuning.dart';
import '../player_projectile_muzzle.dart';
import 'bounty_hunter_geometry.dart';

/// Native cells are composed into one canvas without stretching. The base
/// body's support line is aligned with the larger add-on's feet.
RenderAnimSetDefinition bountyHunterRenderAnim(ProjectileId weapon) {
  final variant = switch (weapon) {
    ProjectileId.hunterCrossbow ||
    ProjectileId.hunterLongwatchCrossbow ||
    ProjectileId.hunterHeavyLimbCrossbow => 'crossbow',
    ProjectileId.hunterShotgun || ProjectileId.hunterBrushgun => 'shotgun',
    _ => 'gun',
  };
  final prefix = 'entities/player/bounty_hunter/$variant';
  final sources = <AnimKey, String>{};
  final counts = <AnimKey, int>{};
  final times = <AnimKey, double>{};
  final frames = <AnimKey, List<List<RenderFramePart>>>{};
  void strip(
    AnimKey key,
    int row,
    int count,
    double seconds, {
    bool addon = false,
    String? sheet,
    int start = 0,
    int? columns,
  }) {
    final width = addon ? 89 : 73;
    final height = addon ? 65 : 54;
    final cols = columns ?? (addon ? 13 : 8);
    sources[key] =
        '$prefix/${sheet ?? (addon ? 'add_on_sheet.png' : 'sprite_sheet.png')}';
    counts[key] = count;
    times[key] = seconds;
    frames[key] = List.generate(
      count,
      (i) => [
        RenderFramePart(
          source: RenderFrameRect(
            ((start + i) % cols) * width,
            (row + (start + i) ~/ cols) * height,
            width,
            height,
          ),
          position: addon ? const Vec2(0, 0) : const Vec2(6, 11),
          size: Vec2(width.toDouble(), height.toDouble()),
        ),
      ],
    );
  }

  strip(AnimKey.idle, 0, 8, .12);
  strip(AnimKey.spawn, 0, 8, .06);
  strip(AnimKey.walk, 2, 8, .12);
  strip(AnimKey.run, 2, 8, .075);
  strip(AnimKey.jump, 4, 4, .09);
  strip(AnimKey.fall, 5, 3, .10);
  strip(AnimKey.hit, 0, 3, .09, sheet: 'hurt_no_effect_sheet.png', columns: 3);
  strip(AnimKey.stun, 0, 3, .15, sheet: 'hurt_no_effect_sheet.png', columns: 3);
  strip(
    AnimKey.airHit,
    1,
    3,
    .09,
    sheet: 'hurt_no_effect_sheet.png',
    columns: 3,
  );
  strip(AnimKey.death, 9, 7, .10);
  strip(AnimKey.airDeath, 8, 3, .10);
  strip(AnimKey.ranged, 14, 3, .06);
  strip(AnimKey.rangedAir, 15, 3, .06);
  // Three firing phases, each containing eight running poses.
  strip(AnimKey.rangedRun, 0, 24, .075, sheet: 'run_shoot_sheet.png');
  strip(AnimKey.dash, 18, 7, .04);
  strip(AnimKey.slide, 22, 4, .06);
  strip(AnimKey.roll, 23, 7, .05);
  strip(AnimKey.strike, 25, 7, .06);
  // Keep the add-on's two blade swings; frame 9 starts drawing the ranged weapon.
  strip(AnimKey.twinStrike, 2, 8, .06, addon: true);
  strip(AnimKey.lunge, 29, 5, .05);
  // The atlas omits source frame 5: restore its intentional disappearance
  // between the two streak poses without adding a second sprite asset.
  strip(AnimKey.teleportOut, 27, 9, .05);
  frames[AnimKey.teleportOut]!.insert(4, const []);
  counts[AnimKey.teleportOut] = 10;
  strip(AnimKey.bombDrop, 3, 10, .05, addon: true);
  strip(AnimKey.doubleJump, 8, 6, .06, addon: true);
  // Fieldcraft has no dedicated cast art; a brief ready pose preserves its gun.
  strip(AnimKey.cast, 0, 1, .1);
  return RenderAnimSetDefinition(
    frameWidth: 89,
    frameHeight: 65,
    anchorPoint: const Vec2(34, 47),
    sourcesByKey: sources,
    frameCountsByKey: counts,
    stepTimeSecondsByKey: times,
    compositeFramesByKey: frames,
    dashHoldFrame: 3,
  );
}

const bountyHunterCatalog = PlayerCatalog(
  bodyTemplate: BodyDef(
    isKinematic: false,
    useGravity: true,
    ignoreCeilings: false,
    topOnlyGround: true,
    gravityScale: 1,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  // World-unit literals retain the Entities editor's guarded scalar bindings.
  colliderWidth: 21.6,
  colliderHeight: 43.2,
  colliderOffsetX: 0,
  colliderOffsetY: 1.35,
  castOriginOffset: 29.7,
  tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
  resistance: DamageResistanceDef(),
  statusImmunity: StatusImmunityDef(),
  loadoutSlotMask: LoadoutSlotMask.all,
  weaponId: WeaponId.hunterBlade,
  offhandWeaponId: WeaponId.hunterBombKit,
  spellBookId: SpellBookId.hunterFieldKit,
  projectileSlotSpellId: ProjectileId.hunterPistol,
  startingProjectileSpellIds: {
    ProjectileId.hunterPistol,
    ProjectileId.hunterCrossbow,
    ProjectileId.hunterShotgun,
  },
  abilityPrimaryId: 'bounty_hunter.quick_cut',
  abilitySecondaryId: 'bounty_hunter.blast_bomb',
  abilityProjectileId: 'bounty_hunter.snap_shot',
  abilitySpellId: 'bounty_hunter.hunters_focus',
  startingSpellAbilityIds: <AbilityKey>{
    'bounty_hunter.hunters_focus',
    'bounty_hunter.prepare_charges',
  },
  abilityMobilityId: 'bounty_hunter.dash',
  abilityJumpId: 'bounty_hunter.jump',
  facing: Facing.right,
);

const bountyHunterTuning = PlayerTuning(
  movement: MovementTuning(
    maxSpeedX: 200,
    accelerationX: 600,
    decelerationX: 1200,
    minMoveSpeed: 5,
    runSpeedThresholdX: 120,
    maxVelX: 1500,
    maxVelY: 1500,
    jumpSpeed: 500,
    coyoteTimeSeconds: .1,
    jumpBufferSeconds: .12,
    dashDurationSeconds: .2,
    dashCooldownSeconds: 2,
  ),
  resource: ResourceTuning(
    playerHpMax: 90,
    playerHpRegenPerSecond: .5,
    playerManaMax: 100,
    playerManaRegenPerSecond: 3,
    playerStaminaMax: 100,
    playerStaminaRegenPerSecond: 1.5,
    jumpStaminaCost: 2,
    dashStaminaCost: 2,
  ),
  anim: AnimTuning(
    hitAnimSeconds: .27,
    deathAnimSeconds: .7,
    spawnAnimSeconds: .48,
  ),
  combat: CombatTuning(invulnerabilitySeconds: .25),
);

// Release-frame barrel endpoints measured in native 73x54 base cells. Apply
// the (6,11) composition and (34,47) pivot before converting to world units.
PlayerProjectileMuzzle _muzzle(Vec2 ground, Vec2 air, List<Vec2> run) {
  Vec2 world(Vec2 p) => Vec2(
    (p.x - 28) * bountyHunterWorldScale,
    (p.y - 36) * bountyHunterWorldScale,
  );
  return PlayerProjectileMuzzle(
    standing: world(ground),
    airborne: world(air),
    running: run.map(world).toList(growable: false),
  );
}

final bountyHunterCharacter = PlayerCharacterDefinition(
  id: PlayerCharacterId.bountyHunter,
  displayName: 'Willow',
  renderScale: bountyHunterWorldScale,
  renderAnim: bountyHunterRenderAnim(ProjectileId.hunterPistol),
  catalog: bountyHunterCatalog,
  tuning: bountyHunterTuning,
  projectileMuzzles: {
    for (final id in [
      ProjectileId.hunterPistol,
      ProjectileId.hunterRoadsidePistol,
      ProjectileId.hunterLongbarrelPistol,
    ])
      id: _muzzle(const Vec2(47, 20), const Vec2(51, 26), const [
        Vec2(45, 21),
        Vec2(44, 19),
        Vec2(45, 20),
        Vec2(45, 22),
        Vec2(46, 22),
        Vec2(45, 20),
        Vec2(46, 20),
        Vec2(46, 22),
      ]),
    for (final id in [
      ProjectileId.hunterCrossbow,
      ProjectileId.hunterLongwatchCrossbow,
      ProjectileId.hunterHeavyLimbCrossbow,
    ])
      id: _muzzle(const Vec2(48, 23.5), const Vec2(52, 30.5), const [
        Vec2(46, 23.5),
        Vec2(45, 21.5),
        Vec2(46, 22.5),
        Vec2(46, 24.5),
        Vec2(47, 24.5),
        Vec2(46, 22.5),
        Vec2(47, 22.5),
        Vec2(47, 24.5),
      ]),
    for (final id in [ProjectileId.hunterShotgun, ProjectileId.hunterBrushgun])
      id: _muzzle(const Vec2(49, 19), const Vec2(53, 25), const [
        Vec2(48, 19),
        Vec2(46, 18),
        Vec2(47, 19),
        Vec2(48, 20),
        Vec2(49, 20),
        Vec2(47, 19),
        Vec2(48, 19),
        Vec2(49, 20),
      ]),
  },
  renderVariants: {
    for (final id in hunterRangedWeaponIds) id: bountyHunterRenderAnim(id),
  },
);
