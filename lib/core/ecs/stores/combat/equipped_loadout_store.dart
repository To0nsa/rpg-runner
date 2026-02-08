import '../../../projectiles/projectile_item_id.dart';
import '../../../spells/spell_book_id.dart';
import '../../../accessories/accessory_id.dart';
import '../../../weapons/weapon_id.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';
import '../../../abilities/ability_def.dart';

/// Bitmask constants for loadout slots.
///
/// Each bit represents a slot that a character may or may not have access to.
/// Use these to check/set which equipment slots are enabled for an entity.
class LoadoutSlotMask {
  const LoadoutSlotMask._();

  /// Main hand weapon slot (melee).
  static const int mainHand = 1 << 0;

  /// Off-hand slot (shield or secondary weapon).
  static const int offHand = 1 << 1;

  /// Projectile slot (spells or throwing weapons).
  static const int projectile = 1 << 2;

  /// All slots enabled.
  static const int all = mainHand | offHand | projectile;

  /// Default slots for most characters (no off-hand).
  static const int defaultMask = mainHand | projectile;
}

/// Definition for creating an equipped loadout component.
class EquippedLoadoutDef {
  const EquippedLoadoutDef({
    this.mask = LoadoutSlotMask.defaultMask,
    this.mainWeaponId = WeaponId.woodenSword,
    this.offhandWeaponId = WeaponId.woodenShield,
    this.projectileItemId = ProjectileItemId.throwingKnife,
    this.spellBookId = SpellBookId.basicSpellBook,
    this.projectileSlotSpellId = ProjectileItemId.iceBolt,
    this.bonusSlotSpellId = ProjectileItemId.fireBolt,
    this.accessoryId = AccessoryId.speedBoots,
    this.abilityPrimaryId = 'eloise.sword_strike',
    this.abilitySecondaryId = 'eloise.shield_block',
    this.abilityProjectileId = 'eloise.quick_shot',
    this.abilityBonusId = 'eloise.charged_shot',
    this.abilityMobilityId = 'eloise.dash',
    this.abilityJumpId = 'eloise.jump',
  });

  /// Bitmask of enabled slots (see [LoadoutSlotMask]).
  final int mask;

  /// Main hand weapon.
  final WeaponId mainWeaponId;

  /// Off-hand weapon or shield.
  final WeaponId offhandWeaponId;

  /// Equipped projectile item fallback (typically throwing weapon).
  final ProjectileItemId projectileItemId;

  /// Equipped spell book (spell payload provider).
  final SpellBookId spellBookId;

  /// Optional projectile spell selection for [AbilitySlot.projectile].
  ///
  /// If null, projectile abilities in the projectile slot use [projectileItemId].
  final ProjectileItemId? projectileSlotSpellId;

  /// Optional projectile spell selection for [AbilitySlot.bonus].
  ///
  /// If null, projectile abilities in the bonus slot use [projectileItemId].
  final ProjectileItemId? bonusSlotSpellId;

  /// Equipped accessory (meta gear; not yet wired into Core systems).
  final AccessoryId accessoryId;

  // New Ability System IDs
  final AbilityKey abilityPrimaryId;
  final AbilityKey abilitySecondaryId;
  final AbilityKey abilityProjectileId;
  final AbilityKey abilityBonusId;
  final AbilityKey abilityMobilityId;
  final AbilityKey abilityJumpId;
}

/// Per-entity equipment loadout (single source of truth).
///
/// This store holds all equipped items for an entity in a unified structure.
/// Systems should read from this store for equipment info.
///
/// **Slot mask**: Determines which slots are available for this entity.
/// Use [hasSlot] to check if an entity has a specific slot enabled.
class EquippedLoadoutStore extends SparseSet {
  // SoA fields for each component.
  final List<int> mask = <int>[];
  final List<WeaponId> mainWeaponId = <WeaponId>[];
  final List<WeaponId> offhandWeaponId = <WeaponId>[];
  final List<ProjectileItemId> projectileItemId = <ProjectileItemId>[];
  final List<SpellBookId> spellBookId = <SpellBookId>[];
  final List<ProjectileItemId?> projectileSlotSpellId = <ProjectileItemId?>[];
  final List<ProjectileItemId?> bonusSlotSpellId = <ProjectileItemId?>[];
  final List<AccessoryId> accessoryId = <AccessoryId>[];

  // New Ability System Lists
  final List<AbilityKey> abilityPrimaryId = <AbilityKey>[];
  final List<AbilityKey> abilitySecondaryId = <AbilityKey>[];
  final List<AbilityKey> abilityProjectileId = <AbilityKey>[];
  final List<AbilityKey> abilityBonusId = <AbilityKey>[];
  final List<AbilityKey> abilityMobilityId = <AbilityKey>[];
  final List<AbilityKey> abilityJumpId = <AbilityKey>[];

  void add(
    EntityId entity, [
    EquippedLoadoutDef def = const EquippedLoadoutDef(),
  ]) {
    final i = addEntity(entity);
    mask[i] = def.mask;
    mainWeaponId[i] = def.mainWeaponId;
    offhandWeaponId[i] = def.offhandWeaponId;
    projectileItemId[i] = def.projectileItemId;
    spellBookId[i] = def.spellBookId;
    projectileSlotSpellId[i] = def.projectileSlotSpellId;
    bonusSlotSpellId[i] = def.bonusSlotSpellId;
    accessoryId[i] = def.accessoryId;
    abilityPrimaryId[i] = def.abilityPrimaryId;
    abilitySecondaryId[i] = def.abilitySecondaryId;
    abilityProjectileId[i] = def.abilityProjectileId;
    abilityBonusId[i] = def.abilityBonusId;
    abilityMobilityId[i] = def.abilityMobilityId;
    abilityJumpId[i] = def.abilityJumpId;
  }

  /// Updates the loadout for an existing entity.
  void set(EntityId entity, EquippedLoadoutDef def) {
    final i = indexOf(entity);
    mask[i] = def.mask;
    mainWeaponId[i] = def.mainWeaponId;
    offhandWeaponId[i] = def.offhandWeaponId;
    projectileItemId[i] = def.projectileItemId;
    spellBookId[i] = def.spellBookId;
    projectileSlotSpellId[i] = def.projectileSlotSpellId;
    bonusSlotSpellId[i] = def.bonusSlotSpellId;
    accessoryId[i] = def.accessoryId;
    abilityPrimaryId[i] = def.abilityPrimaryId;
    abilitySecondaryId[i] = def.abilitySecondaryId;
    abilityProjectileId[i] = def.abilityProjectileId;
    abilityBonusId[i] = def.abilityBonusId;
    abilityMobilityId[i] = def.abilityMobilityId;
    abilityJumpId[i] = def.abilityJumpId;
  }

  /// Returns true if [entity] has the given [slotBit] enabled.
  bool hasSlot(EntityId entity, int slotBit) {
    final i = tryIndexOf(entity);
    if (i == null) return false;
    return (mask[i] & slotBit) != 0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    mask.add(LoadoutSlotMask.defaultMask);
    mainWeaponId.add(WeaponId.woodenSword);
    offhandWeaponId.add(WeaponId.woodenShield);
    projectileItemId.add(ProjectileItemId.throwingKnife);
    spellBookId.add(SpellBookId.basicSpellBook);
    projectileSlotSpellId.add(ProjectileItemId.iceBolt);
    bonusSlotSpellId.add(ProjectileItemId.fireBolt);
    accessoryId.add(AccessoryId.speedBoots);
    abilityPrimaryId.add('eloise.sword_strike');
    abilitySecondaryId.add('eloise.shield_block');
    abilityProjectileId.add('eloise.quick_shot');
    abilityBonusId.add('eloise.charged_shot');
    abilityMobilityId.add('eloise.dash');
    abilityJumpId.add('eloise.jump');
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    mask[removeIndex] = mask[lastIndex];
    mainWeaponId[removeIndex] = mainWeaponId[lastIndex];
    offhandWeaponId[removeIndex] = offhandWeaponId[lastIndex];
    projectileItemId[removeIndex] = projectileItemId[lastIndex];
    spellBookId[removeIndex] = spellBookId[lastIndex];
    projectileSlotSpellId[removeIndex] = projectileSlotSpellId[lastIndex];
    bonusSlotSpellId[removeIndex] = bonusSlotSpellId[lastIndex];
    accessoryId[removeIndex] = accessoryId[lastIndex];
    abilityPrimaryId[removeIndex] = abilityPrimaryId[lastIndex];
    abilitySecondaryId[removeIndex] = abilitySecondaryId[lastIndex];
    abilityProjectileId[removeIndex] = abilityProjectileId[lastIndex];
    abilityBonusId[removeIndex] = abilityBonusId[lastIndex];
    abilityMobilityId[removeIndex] = abilityMobilityId[lastIndex];
    abilityJumpId[removeIndex] = abilityJumpId[lastIndex];

    mask.removeLast();
    mainWeaponId.removeLast();
    offhandWeaponId.removeLast();
    projectileItemId.removeLast();
    spellBookId.removeLast();
    projectileSlotSpellId.removeLast();
    bonusSlotSpellId.removeLast();
    accessoryId.removeLast();
    abilityPrimaryId.removeLast();
    abilitySecondaryId.removeLast();
    abilityProjectileId.removeLast();
    abilityBonusId.removeLast();
    abilityMobilityId.removeLast();
    abilityJumpId.removeLast();
  }
}
