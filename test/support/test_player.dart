import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/creature_tag.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/creature_tag_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/damage_resistance_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/status_immunity_store.dart';
import 'package:rpg_runner/core/players/player_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spells/spell_book_id.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

const Object _unset = Object();

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
  weaponId: WeaponId.basicSword,
  offhandWeaponId: WeaponId.basicShield,
  projectileItemId: ProjectileItemId.fireBolt,
  spellBookId: SpellBookId.basicSpellBook,
  projectileSlotSpellId: ProjectileItemId.iceBolt,
  abilityPrimaryId: 'eloise.sword_strike',
  abilitySecondaryId: 'eloise.shield_block',
  abilityProjectileId: 'eloise.charged_shot',
  abilityBonusId: 'eloise.arcane_haste',
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
  ProjectileItemId? projectileItemId,
  SpellBookId? spellBookId,
  Object? projectileSlotSpellId = _unset,
  AbilityKey? abilityPrimaryId,
  AbilityKey? abilitySecondaryId,
  AbilityKey? abilityProjectileId,
  AbilityKey? abilityBonusId,
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
    projectileItemId:
        projectileItemId ?? testPlayerCatalogDefaults.projectileItemId,
    spellBookId: spellBookId ?? testPlayerCatalogDefaults.spellBookId,
    projectileSlotSpellId: identical(projectileSlotSpellId, _unset)
        ? testPlayerCatalogDefaults.projectileSlotSpellId
        : projectileSlotSpellId as ProjectileItemId?,
    abilityPrimaryId:
        abilityPrimaryId ?? testPlayerCatalogDefaults.abilityPrimaryId,
    abilitySecondaryId:
        abilitySecondaryId ?? testPlayerCatalogDefaults.abilitySecondaryId,
    abilityProjectileId:
        abilityProjectileId ?? testPlayerCatalogDefaults.abilityProjectileId,
    abilityBonusId: abilityBonusId ?? testPlayerCatalogDefaults.abilityBonusId,
    abilityMobilityId:
        abilityMobilityId ?? testPlayerCatalogDefaults.abilityMobilityId,
    abilityJumpId: abilityJumpId ?? testPlayerCatalogDefaults.abilityJumpId,
    facing: facing ?? testPlayerCatalogDefaults.facing,
  );
}
