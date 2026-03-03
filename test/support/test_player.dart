import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/creature_tag.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/creature_tag_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/status_immunity_store.dart';
import 'package:rpg_runner/core/players/player_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

const PlayerCatalog testPlayerCatalogDefaults = PlayerCatalog(
  bodyTemplate: BodyDef(
    isKinematic: false,
    useGravity: true,
    ignoreCeilings: false,
    topOnlyGround: true,
    gravityScale: 1.0,
    sideMask: BodyDef.sideLeft | BodyDef.sideRight,
  ),
  colliderWidth: 22.0,
  colliderHeight: 46.0,
  colliderOffsetX: 0.0,
  colliderOffsetY: -6.0,
  tags: CreatureTagDef(mask: CreatureTagMask.humanoid),
  resistance: DamageResistanceDef(),
  statusImmunity: StatusImmunityDef(),
  loadoutSlotMask: LoadoutSlotMask.defaultMask,
  weaponId: WeaponId.plainsteel,
  offhandWeaponId: WeaponId.roadguard,
  spellBookId: SpellBookId.apprenticePrimer,
  projectileSlotSpellId: ProjectileId.fireBolt,
  abilityPrimaryId: 'eloise.bloodletter_slash',
  abilitySecondaryId: 'eloise.aegis_riposte',
  abilityProjectileId: 'eloise.overcharge_shot',
  abilitySpellId: 'eloise.arcane_haste',
  abilityMobilityId: 'eloise.dash',
  abilityJumpId: 'eloise.jump',
  facing: Facing.right,
);

PlayerCatalog testPlayerCatalog({
  BodyDef? bodyTemplate,
  double? colliderWidth,
  double? colliderHeight,
  double? colliderOffsetX,
  double? colliderOffsetY,
  CreatureTagDef? tags,
  DamageResistanceDef? resistance,
  StatusImmunityDef? statusImmunity,
  int? loadoutSlotMask,
  WeaponId? weaponId,
  WeaponId? offhandWeaponId,
  SpellBookId? spellBookId,
  ProjectileId? projectileId,
  ProjectileId? projectileSlotSpellId,
  bool? projectileSlotAllowsThrowingWeapon,
  AbilityKey? abilityPrimaryId,
  AbilityKey? abilitySecondaryId,
  AbilityKey? abilityProjectileId,
  AbilityKey? abilitySpellId,
  AbilityKey? abilityMobilityId,
  AbilityKey? abilityJumpId,
  Facing? facing,
}) {
  return PlayerCatalog(
    bodyTemplate: bodyTemplate ?? testPlayerCatalogDefaults.bodyTemplate,
    colliderWidth: colliderWidth ?? testPlayerCatalogDefaults.colliderWidth,
    colliderHeight: colliderHeight ?? testPlayerCatalogDefaults.colliderHeight,
    colliderOffsetX:
        colliderOffsetX ?? testPlayerCatalogDefaults.colliderOffsetX,
    colliderOffsetY:
        colliderOffsetY ?? testPlayerCatalogDefaults.colliderOffsetY,
    tags: tags ?? testPlayerCatalogDefaults.tags,
    resistance: resistance ?? testPlayerCatalogDefaults.resistance,
    statusImmunity: statusImmunity ?? testPlayerCatalogDefaults.statusImmunity,
    loadoutSlotMask:
        loadoutSlotMask ?? testPlayerCatalogDefaults.loadoutSlotMask,
    weaponId: weaponId ?? testPlayerCatalogDefaults.weaponId,
    offhandWeaponId:
        offhandWeaponId ?? testPlayerCatalogDefaults.offhandWeaponId,
    spellBookId: spellBookId ?? testPlayerCatalogDefaults.spellBookId,
    projectileSlotSpellId:
        projectileSlotSpellId ??
        projectileId ??
        testPlayerCatalogDefaults.projectileSlotSpellId,
    abilityPrimaryId:
        abilityPrimaryId ?? testPlayerCatalogDefaults.abilityPrimaryId,
    abilitySecondaryId:
        abilitySecondaryId ?? testPlayerCatalogDefaults.abilitySecondaryId,
    abilityProjectileId:
        abilityProjectileId ?? testPlayerCatalogDefaults.abilityProjectileId,
    abilitySpellId: abilitySpellId ?? testPlayerCatalogDefaults.abilitySpellId,
    abilityMobilityId:
        abilityMobilityId ?? testPlayerCatalogDefaults.abilityMobilityId,
    abilityJumpId: abilityJumpId ?? testPlayerCatalogDefaults.abilityJumpId,
    facing: facing ?? testPlayerCatalogDefaults.facing,
  );
}
