// Presenter helpers for ability selection UI.
//
// This file translates authoritative Core loadout/catalog data into UI-facing
// models, runs trial-loadout legality checks through `LoadoutValidator`, and
// provides immutable slot update helpers for widgets.
//
// Keeping this logic centralized ensures picker screens stay aligned with Core
// rules (visibility, legality, and source constraints) without mutating
// loadouts directly in widget code.
import '../../../../core/abilities/ability_catalog.dart';
import '../../../../core/abilities/ability_def.dart';
import '../../../../core/accessories/accessory_id.dart';
import '../../../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../../../core/loadout/loadout_validator.dart';
import '../../../../core/meta/spell_list.dart';
import '../../../../core/players/character_ability_namespace.dart';
import '../../../../core/players/player_character_definition.dart';
import '../../../../core/players/player_character_registry.dart';
import '../../../../core/projectiles/projectile_catalog.dart';
import '../../../../core/projectiles/projectile_id.dart';
import '../../../../core/spellBook/spell_book_catalog.dart';
import '../../../../core/spellBook/spell_book_id.dart';
import '../../../../core/weapons/weapon_catalog.dart';
import '../../../../core/weapons/weapon_id.dart';
import '../../../text/gear_text.dart';

const AbilityCatalog _abilityCatalog = AbilityCatalog();
const ProjectileCatalog _projectileCatalog = ProjectileCatalog();
const SpellBookCatalog _spellBookCatalog = SpellBookCatalog();
const LoadoutValidator _loadoutValidator = LoadoutValidator(
  abilityCatalog: _abilityCatalog,
  weaponCatalog: WeaponCatalog(),
  projectileCatalog: _projectileCatalog,
  spellBookCatalog: _spellBookCatalog,
);

/// Display model for one ability option in a picker.
///
/// [isEnabled] represents legality for the current trial loadout, not unlock
/// ownership. UI can still render disabled entries for discoverability.
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
/// - [spellId] != null means "use this learned spell from Spell List".
class ProjectileSourceOption {
  const ProjectileSourceOption({
    required this.projectileId,
    required this.spellId,
    required this.displayName,
    this.description = '',
    this.damageTypeName = '',
    this.statusLines = const <String>[],
  });

  /// Canonical [ProjectileId] for this source (used for icon lookup).
  final ProjectileId projectileId;

  final ProjectileId? spellId;
  final String displayName;

  /// Short description of what this projectile does.
  final String description;

  /// User-facing damage type label (e.g. "Fire", "Physical").
  final String damageTypeName;

  /// Detailed status effect summaries with numbers.
  final List<String> statusLines;
}

/// Display model for the left projectile source panel.
///
/// It explicitly separates source families:
/// - equipped throwing weapon (single tap-select entry)
/// - learned projectile spells from Spell List
class ProjectileSourcePanelModel {
  const ProjectileSourcePanelModel({
    required this.throwingWeaponId,
    required this.throwingWeaponDisplayName,
    required this.spellListDisplayName,
    required this.spellOptions,
  });

  final ProjectileId throwingWeaponId;
  final String throwingWeaponDisplayName;
  final String spellListDisplayName;
  final List<ProjectileSpellOption> spellOptions;
}

/// Display model for one learned projectile spell in the spell list.
class ProjectileSpellOption {
  const ProjectileSpellOption({
    required this.spellId,
    required this.displayName,
  });

  final ProjectileId spellId;
  final String displayName;
}

/// Returns all visible ability candidates for [slot] under the current loadout.
///
/// Legality is validated through [LoadoutValidator] so UI remains Core-driven.
/// The returned list is sorted by id for deterministic UI ordering.
List<AbilityPickerCandidate> abilityCandidatesForSlot({
  required PlayerCharacterId characterId,
  required AbilitySlot slot,
  required EquippedLoadoutDef loadout,
  required SpellList spellList,
  ProjectileId? selectedSourceSpellId,
  bool overrideSelectedSource = false,
}) {
  final normalizedLoadout = normalizeLoadoutMaskForCharacter(
    characterId: characterId,
    loadout: loadout,
  );
  final candidates = <AbilityDef>[
    for (final def in AbilityCatalog.abilities.values)
      if (_isAbilityVisibleForCharacter(characterId, def.id) &&
          (slot != AbilitySlot.spell ||
              spellList.learnedSpellAbilityIds.contains(def.id)) &&
          def.allowedSlots.contains(slot))
        def,
  ];

  final equippedAbilityId = abilityIdForSlot(normalizedLoadout, slot);
  final equippedAbility = _abilityCatalog.resolve(equippedAbilityId);
  // Keep currently equipped ability visible even when character visibility
  // rules changed, so the player can always see and replace invalid legacy
  // selections.
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
  final def = PlayerCharacterRegistry.resolve(characterId);
  final targetMask = def.catalog.loadoutSlotMask;
  if (loadout.mask == targetMask) return loadout;
  return _copyLoadout(loadout, mask: targetMask);
}

/// Returns projectile source options exposed by the equipped throwing weapon
/// and character spell list.
ProjectileSourcePanelModel projectileSourcePanelModel(
  EquippedLoadoutDef loadout,
  SpellList spellList,
) {
  final spellOptions = <ProjectileSpellOption>[];
  final orderedLearned = spellList.learnedProjectileSpellIds.toList(
    growable: false,
  )..sort((a, b) => a.index.compareTo(b.index));
  for (final spellId in orderedLearned) {
    final spellItem = _projectileCatalog.tryGet(spellId);
    if (spellItem == null || spellItem.weaponType != WeaponType.spell) {
      continue;
    }
    spellOptions.add(
      ProjectileSpellOption(
        spellId: spellId,
        displayName: projectileDisplayName(spellId),
      ),
    );
  }
  return ProjectileSourcePanelModel(
    throwingWeaponId: loadout.projectileId,
    throwingWeaponDisplayName: projectileDisplayName(loadout.projectileId),
    spellListDisplayName: 'Spell List',
    spellOptions: spellOptions,
  );
}

/// Returns flat projectile source options for compatibility with existing call sites.
///
/// `spellId == null` always represents the equipped throwing weapon source.
List<ProjectileSourceOption> projectileSourceOptions(
  EquippedLoadoutDef loadout,
  SpellList spellList,
) {
  final sourceModel = projectileSourcePanelModel(loadout, spellList);
  final throwingDef = _projectileCatalog.get(sourceModel.throwingWeaponId);
  final options = <ProjectileSourceOption>[
    ProjectileSourceOption(
      projectileId: sourceModel.throwingWeaponId,
      spellId: null,
      displayName: sourceModel.throwingWeaponDisplayName,
      description: projectileDescription(sourceModel.throwingWeaponId),
      damageTypeName: damageTypeDisplayName(throwingDef.damageType),
      statusLines: projectileStatusSummaries(throwingDef),
    ),
  ];
  for (final spell in sourceModel.spellOptions) {
    final spellDef = _projectileCatalog.get(spell.spellId);
    options.add(
      ProjectileSourceOption(
        projectileId: spell.spellId,
        spellId: spell.spellId,
        displayName: spell.displayName,
        description: projectileDescription(spell.spellId),
        damageTypeName: damageTypeDisplayName(spellDef.damageType),
        statusLines: projectileStatusSummaries(spellDef),
      ),
    );
  }
  return options;
}

/// Returns [selected] when still valid for the current spell list.
ProjectileId? normalizeProjectileSourceSelection(
  EquippedLoadoutDef loadout,
  SpellList spellList,
  ProjectileId? selected,
) {
  if (selected == null) return null;
  final options = projectileSourceOptions(loadout, spellList);
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
    case AbilitySlot.spell:
      return loadout.abilitySpellId;
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
    abilitySpellId: slot == AbilitySlot.spell ? abilityId : null,
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
  required ProjectileId? selectedSpellId,
}) {
  switch (slot) {
    case AbilitySlot.projectile:
      return _copyLoadout(loadout, projectileSlotSpellId: selectedSpellId);
    case AbilitySlot.primary:
    case AbilitySlot.secondary:
    case AbilitySlot.spell:
    case AbilitySlot.mobility:
    case AbilitySlot.jump:
      return loadout;
  }
}

/// Returns whether [id] should appear in the picker for [characterId].
///
/// Character-prefixed and non-enemy common abilities are visible.
bool _isAbilityVisibleForCharacter(
  PlayerCharacterId characterId,
  AbilityKey id,
) {
  final namespace = characterAbilityNamespace(characterId);
  if (id.startsWith('$namespace.')) return true;
  if (id.startsWith('common.') && !id.startsWith('common.enemy_')) return true;
  return false;
}

/// Validates a trial loadout with [abilityId] in [slot] against Core rules.
///
/// Returns `false` when the validator reports any issue for the target slot.
bool _isAbilityLegalForSlot({
  required EquippedLoadoutDef loadout,
  required AbilitySlot slot,
  required AbilityKey abilityId,
  required ProjectileId? selectedSourceSpellId,
  required bool overrideSelectedSource,
}) {
  // Validate a trial loadout so legality always mirrors Core loadout rules.
  var trial = setAbilityForSlot(loadout, slot: slot, abilityId: abilityId);
  if (overrideSelectedSource && slot == AbilitySlot.projectile) {
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

/// Copies [loadout] while preserving omitted fields.
///
/// [projectileSlotSpellId] uses [_keepValue] to distinguish "leave unchanged"
/// from an intentional `null` assignment.
EquippedLoadoutDef _copyLoadout(
  EquippedLoadoutDef loadout, {
  int? mask,
  WeaponId? mainWeaponId,
  WeaponId? offhandWeaponId,
  ProjectileId? projectileId,
  SpellBookId? spellBookId,
  Object? projectileSlotSpellId = _keepValue,
  AccessoryId? accessoryId,
  AbilityKey? abilityPrimaryId,
  AbilityKey? abilitySecondaryId,
  AbilityKey? abilityProjectileId,
  AbilityKey? abilitySpellId,
  AbilityKey? abilityMobilityId,
  AbilityKey? abilityJumpId,
}) {
  return EquippedLoadoutDef(
    mask: mask ?? loadout.mask,
    mainWeaponId: mainWeaponId ?? loadout.mainWeaponId,
    offhandWeaponId: offhandWeaponId ?? loadout.offhandWeaponId,
    projectileId: projectileId ?? loadout.projectileId,
    spellBookId: spellBookId ?? loadout.spellBookId,
    projectileSlotSpellId: identical(projectileSlotSpellId, _keepValue)
        ? loadout.projectileSlotSpellId
        : projectileSlotSpellId as ProjectileId?,
    accessoryId: accessoryId ?? loadout.accessoryId,
    abilityPrimaryId: abilityPrimaryId ?? loadout.abilityPrimaryId,
    abilitySecondaryId: abilitySecondaryId ?? loadout.abilitySecondaryId,
    abilityProjectileId: abilityProjectileId ?? loadout.abilityProjectileId,
    abilitySpellId: abilitySpellId ?? loadout.abilitySpellId,
    abilityMobilityId: abilityMobilityId ?? loadout.abilityMobilityId,
    abilityJumpId: abilityJumpId ?? loadout.abilityJumpId,
  );
}

/// Sentinel used by [_copyLoadout] for nullable override semantics.
const Object _keepValue = Object();
