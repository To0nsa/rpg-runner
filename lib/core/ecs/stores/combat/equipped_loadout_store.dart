import '../../../projectiles/projectile_item_id.dart';
import '../../../spells/spell_book_id.dart';
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
    this.mainWeaponId = WeaponId.basicSword,
    this.offhandWeaponId = WeaponId.basicShield,
    this.projectileItemId = ProjectileItemId.fireBolt,
    this.spellBookId = SpellBookId.basicSpellbook,
    this.abilityPrimaryId = 'eloise.sword_strike',
    this.abilitySecondaryId = 'eloise.shield_block',
    this.abilityProjectileId = 'eloise.fire_bolt',
    this.abilityBonusId = 'eloise.shield_bash',
    this.abilityMobilityId = 'eloise.dash',
    this.abilityJumpId = 'eloise.jump',
  });

  /// Bitmask of enabled slots (see [LoadoutSlotMask]).
  final int mask;

  /// Main hand weapon.
  final WeaponId mainWeaponId;

  /// Off-hand weapon or shield.
  final WeaponId offhandWeaponId;

  /// Equipped projectile item (spell or throwing weapon).
  final ProjectileItemId projectileItemId;

  /// Equipped spell book (spell payload provider).
  final SpellBookId spellBookId;

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
  
  // New Ability System Lists
  final List<AbilityKey> abilityPrimaryId = <AbilityKey>[];
  final List<AbilityKey> abilitySecondaryId = <AbilityKey>[];
  final List<AbilityKey> abilityProjectileId = <AbilityKey>[];
  final List<AbilityKey> abilityBonusId = <AbilityKey>[];
  final List<AbilityKey> abilityMobilityId = <AbilityKey>[];
  final List<AbilityKey> abilityJumpId = <AbilityKey>[];

  void add(EntityId entity, [EquippedLoadoutDef def = const EquippedLoadoutDef()]) {
    final i = addEntity(entity);
    mask[i] = def.mask;
    mainWeaponId[i] = def.mainWeaponId;
    offhandWeaponId[i] = def.offhandWeaponId;
    projectileItemId[i] = def.projectileItemId;
    spellBookId[i] = def.spellBookId;
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
    mainWeaponId.add(WeaponId.basicSword);
    offhandWeaponId.add(WeaponId.basicShield);
    projectileItemId.add(ProjectileItemId.iceBolt);
    spellBookId.add(SpellBookId.basicSpellbook);
    abilityPrimaryId.add('eloise.sword_strike');
    abilitySecondaryId.add('eloise.shield_block');
    abilityProjectileId.add('eloise.ice_bolt');
    abilityBonusId.add('eloise.ice_bolt');
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
    abilityPrimaryId.removeLast();
    abilitySecondaryId.removeLast();
    abilityProjectileId.removeLast();
    abilityBonusId.removeLast();
    abilityMobilityId.removeLast();
    abilityJumpId.removeLast();
  }
}
