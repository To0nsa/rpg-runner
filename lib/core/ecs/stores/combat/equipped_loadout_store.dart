import '../../../spells/spell_id.dart';
import '../../../weapons/ranged_weapon_id.dart';
import '../../../weapons/weapon_id.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

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

  /// Ranged weapon slot (bow, throwing axe).
  static const int ranged = 1 << 2;

  /// Spell slot.
  static const int spell = 1 << 3;

  /// All slots enabled.
  static const int all = mainHand | offHand | ranged | spell;

  /// Default slots for most characters (no off-hand).
  static const int defaultMask = mainHand | ranged | spell;
}

/// Definition for creating an equipped loadout component.
class EquippedLoadoutDef {
  const EquippedLoadoutDef({
    this.mask = LoadoutSlotMask.defaultMask,
    this.mainWeaponId = WeaponId.basicSword,
    this.offhandWeaponId = WeaponId.basicShield,
    this.rangedWeaponId = RangedWeaponId.bow,
    this.spellId = SpellId.iceBolt,
  });

  /// Bitmask of enabled slots (see [LoadoutSlotMask]).
  final int mask;

  /// Main hand weapon.
  final WeaponId mainWeaponId;

  /// Off-hand weapon or shield.
  final WeaponId offhandWeaponId;

  /// Ranged weapon.
  final RangedWeaponId rangedWeaponId;

  /// Equipped spell.
  final SpellId spellId;
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
  final List<RangedWeaponId> rangedWeaponId = <RangedWeaponId>[];
  final List<SpellId> spellId = <SpellId>[];

  void add(EntityId entity, [EquippedLoadoutDef def = const EquippedLoadoutDef()]) {
    final i = addEntity(entity);
    mask[i] = def.mask;
    mainWeaponId[i] = def.mainWeaponId;
    offhandWeaponId[i] = def.offhandWeaponId;
    rangedWeaponId[i] = def.rangedWeaponId;
    spellId[i] = def.spellId;
  }

  /// Updates the loadout for an existing entity.
  void set(EntityId entity, EquippedLoadoutDef def) {
    final i = indexOf(entity);
    mask[i] = def.mask;
    mainWeaponId[i] = def.mainWeaponId;
    offhandWeaponId[i] = def.offhandWeaponId;
    rangedWeaponId[i] = def.rangedWeaponId;
    spellId[i] = def.spellId;
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
    rangedWeaponId.add(RangedWeaponId.bow);
    spellId.add(SpellId.iceBolt);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    mask[removeIndex] = mask[lastIndex];
    mainWeaponId[removeIndex] = mainWeaponId[lastIndex];
    offhandWeaponId[removeIndex] = offhandWeaponId[lastIndex];
    rangedWeaponId[removeIndex] = rangedWeaponId[lastIndex];
    spellId[removeIndex] = spellId[lastIndex];

    mask.removeLast();
    mainWeaponId.removeLast();
    offhandWeaponId.removeLast();
    rangedWeaponId.removeLast();
    spellId.removeLast();
  }
}
