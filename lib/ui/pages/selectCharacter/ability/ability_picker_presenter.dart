import '../../../../core/abilities/ability_catalog.dart';
import '../../../../core/abilities/ability_def.dart';
import '../../../../core/accessories/accessory_id.dart';
import '../../../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../../../core/loadout/loadout_validator.dart';
import '../../../../core/players/player_character_definition.dart';
import '../../../../core/players/player_character_registry.dart';
import '../../../../core/projectiles/projectile_item_catalog.dart';
import '../../../../core/projectiles/projectile_item_id.dart';
import '../../../../core/spells/spell_book_catalog.dart';
import '../../../../core/spells/spell_book_id.dart';
import '../../../../core/weapons/weapon_catalog.dart';
import '../../../../core/weapons/weapon_id.dart';

const AbilityCatalog _abilityCatalog = AbilityCatalog();
const ProjectileItemCatalog _projectileCatalog = ProjectileItemCatalog();
const SpellBookCatalog _spellBookCatalog = SpellBookCatalog();
const LoadoutValidator _loadoutValidator = LoadoutValidator(
  abilityCatalog: _abilityCatalog,
  weaponCatalog: WeaponCatalog(),
  projectileItemCatalog: _projectileCatalog,
  spellBookCatalog: _spellBookCatalog,
);

/// Display model for one ability option in a picker.
class AbilityPickerCandidate {
  const AbilityPickerCandidate({
    required this.id,
    required this.def,
    required this.isEnabled,
  });

  final AbilityKey id;
  final AbilityDef def;
  final bool isEnabled;
}

/// Display model for projectile payload selection.
///
/// - [spellId] == null means "use equipped throwing weapon".
/// - [spellId] != null means "use this spell from spellbook".
class ProjectileSourceOption {
  const ProjectileSourceOption({
    required this.spellId,
    required this.displayName,
    required this.isSpell,
  });

  final ProjectileItemId? spellId;
  final String displayName;
  final bool isSpell;
}

/// Returns all legal ability candidates for [slot] under the current loadout.
///
/// Legality is validated through [LoadoutValidator] so UI remains Core-driven.
List<AbilityPickerCandidate> abilityCandidatesForSlot({
  required PlayerCharacterId characterId,
  required AbilitySlot slot,
  required EquippedLoadoutDef loadout,
  ProjectileItemId? selectedSourceSpellId,
  bool overrideSelectedSource = false,
}) {
  final normalizedLoadout = normalizeLoadoutMaskForCharacter(
    characterId: characterId,
    loadout: loadout,
  );
  final candidates = <AbilityDef>[
    for (final def in AbilityCatalog.abilities.values)
      if (_isAbilityVisibleForCharacter(characterId, def.id) &&
          def.allowedSlots.contains(slot))
        def,
  ];

  final equippedAbilityId = abilityIdForSlot(normalizedLoadout, slot);
  final equippedAbility = _abilityCatalog.resolve(equippedAbilityId);
  if (equippedAbility != null &&
      !candidates.any((def) => def.id == equippedAbility.id)) {
    candidates.add(equippedAbility);
  }

  candidates.sort((a, b) => a.id.compareTo(b.id));

  return [
    for (final def in candidates)
      AbilityPickerCandidate(
        id: def.id,
        def: def,
        isEnabled: _isAbilityLegalForSlot(
          loadout: normalizedLoadout,
          slot: slot,
          abilityId: def.id,
          selectedSourceSpellId: selectedSourceSpellId,
          overrideSelectedSource: overrideSelectedSource,
        ),
      ),
  ];
}

/// Forces [loadout.mask] to the selected character's authored slot mask.
///
/// This keeps UI validation and runtime behavior aligned even when older saved
/// selections still carry legacy masks.
EquippedLoadoutDef normalizeLoadoutMaskForCharacter({
  required PlayerCharacterId characterId,
  required EquippedLoadoutDef loadout,
}) {
  final def =
      PlayerCharacterRegistry.byId[characterId] ??
      PlayerCharacterRegistry.defaultCharacter;
  final targetMask = def.catalog.loadoutSlotMask;
  if (loadout.mask == targetMask) return loadout;
  return _copyLoadout(loadout, mask: targetMask);
}

/// Returns projectile source options exposed by the equipped throwing weapon and spellbook.
List<ProjectileSourceOption> projectileSourceOptions(
  EquippedLoadoutDef loadout,
) {
  final throwingWeapon = _projectileCatalog.get(loadout.projectileItemId);
  final spellBook = _spellBookCatalog.get(loadout.spellBookId);
  final options = <ProjectileSourceOption>[
    ProjectileSourceOption(
      spellId: null,
      displayName: throwingWeapon.displayName,
      isSpell: false,
    ),
  ];
  for (final spellId in spellBook.projectileSpellIds) {
    final spell = _projectileCatalog.tryGet(spellId);
    if (spell == null) continue;
    options.add(
      ProjectileSourceOption(
        spellId: spellId,
        displayName: spell.displayName,
        isSpell: true,
      ),
    );
  }
  return options;
}

/// Returns [selected] when still valid for the equipped spellbook, otherwise null.
ProjectileItemId? normalizeProjectileSourceSelection(
  EquippedLoadoutDef loadout,
  ProjectileItemId? selected,
) {
  if (selected == null) return null;
  final options = projectileSourceOptions(loadout);
  final exists = options.any((option) => option.spellId == selected);
  return exists ? selected : null;
}

/// Reads the equipped ability id for [slot].
AbilityKey abilityIdForSlot(EquippedLoadoutDef loadout, AbilitySlot slot) {
  switch (slot) {
    case AbilitySlot.primary:
      return loadout.abilityPrimaryId;
    case AbilitySlot.secondary:
      return loadout.abilitySecondaryId;
    case AbilitySlot.projectile:
      return loadout.abilityProjectileId;
    case AbilitySlot.mobility:
      return loadout.abilityMobilityId;
    case AbilitySlot.jump:
      return loadout.abilityJumpId;
    case AbilitySlot.bonus:
      return loadout.abilityBonusId;
  }
}

/// Returns a copy where [slot] uses [abilityId].
EquippedLoadoutDef setAbilityForSlot(
  EquippedLoadoutDef loadout, {
  required AbilitySlot slot,
  required AbilityKey abilityId,
}) {
  return _copyLoadout(
    loadout,
    abilityPrimaryId: slot == AbilitySlot.primary ? abilityId : null,
    abilitySecondaryId: slot == AbilitySlot.secondary ? abilityId : null,
    abilityProjectileId: slot == AbilitySlot.projectile ? abilityId : null,
    abilityBonusId: slot == AbilitySlot.bonus ? abilityId : null,
    abilityMobilityId: slot == AbilitySlot.mobility ? abilityId : null,
    abilityJumpId: slot == AbilitySlot.jump ? abilityId : null,
  );
}

/// Returns a copy where projectile payload source for [slot] is changed.
///
/// For non-projectile slots this returns the input [loadout] unchanged.
EquippedLoadoutDef setProjectileSourceForSlot(
  EquippedLoadoutDef loadout, {
  required AbilitySlot slot,
  required ProjectileItemId? selectedSpellId,
}) {
  switch (slot) {
    case AbilitySlot.projectile:
      return _copyLoadout(loadout, projectileSlotSpellId: selectedSpellId);
    case AbilitySlot.bonus:
      return _copyLoadout(loadout, bonusSlotSpellId: selectedSpellId);
    case AbilitySlot.primary:
    case AbilitySlot.secondary:
    case AbilitySlot.mobility:
    case AbilitySlot.jump:
      return loadout;
  }
}

bool _isAbilityVisibleForCharacter(
  PlayerCharacterId characterId,
  AbilityKey id,
) {
  if (id.startsWith('${characterId.name}.')) return true;
  if (id.startsWith('common.') && !id.startsWith('common.enemy_')) return true;
  return false;
}

bool _isAbilityLegalForSlot({
  required EquippedLoadoutDef loadout,
  required AbilitySlot slot,
  required AbilityKey abilityId,
  required ProjectileItemId? selectedSourceSpellId,
  required bool overrideSelectedSource,
}) {
  var trial = setAbilityForSlot(loadout, slot: slot, abilityId: abilityId);
  if (overrideSelectedSource &&
      (slot == AbilitySlot.projectile || slot == AbilitySlot.bonus)) {
    trial = setProjectileSourceForSlot(
      trial,
      slot: slot,
      selectedSpellId: selectedSourceSpellId,
    );
  }
  final result = _loadoutValidator.validate(trial);
  for (final issue in result.issues) {
    if (issue.slot == slot) return false;
  }
  return true;
}

EquippedLoadoutDef _copyLoadout(
  EquippedLoadoutDef loadout, {
  int? mask,
  WeaponId? mainWeaponId,
  WeaponId? offhandWeaponId,
  ProjectileItemId? projectileItemId,
  SpellBookId? spellBookId,
  Object? projectileSlotSpellId = _keepValue,
  Object? bonusSlotSpellId = _keepValue,
  AccessoryId? accessoryId,
  AbilityKey? abilityPrimaryId,
  AbilityKey? abilitySecondaryId,
  AbilityKey? abilityProjectileId,
  AbilityKey? abilityBonusId,
  AbilityKey? abilityMobilityId,
  AbilityKey? abilityJumpId,
}) {
  return EquippedLoadoutDef(
    mask: mask ?? loadout.mask,
    mainWeaponId: mainWeaponId ?? loadout.mainWeaponId,
    offhandWeaponId: offhandWeaponId ?? loadout.offhandWeaponId,
    projectileItemId: projectileItemId ?? loadout.projectileItemId,
    spellBookId: spellBookId ?? loadout.spellBookId,
    projectileSlotSpellId: identical(projectileSlotSpellId, _keepValue)
        ? loadout.projectileSlotSpellId
        : projectileSlotSpellId as ProjectileItemId?,
    bonusSlotSpellId: identical(bonusSlotSpellId, _keepValue)
        ? loadout.bonusSlotSpellId
        : bonusSlotSpellId as ProjectileItemId?,
    accessoryId: accessoryId ?? loadout.accessoryId,
    abilityPrimaryId: abilityPrimaryId ?? loadout.abilityPrimaryId,
    abilitySecondaryId: abilitySecondaryId ?? loadout.abilitySecondaryId,
    abilityProjectileId: abilityProjectileId ?? loadout.abilityProjectileId,
    abilityBonusId: abilityBonusId ?? loadout.abilityBonusId,
    abilityMobilityId: abilityMobilityId ?? loadout.abilityMobilityId,
    abilityJumpId: abilityJumpId ?? loadout.abilityJumpId,
  );
}

const Object _keepValue = Object();
