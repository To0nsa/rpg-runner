// Presenter helpers for ability selection UI.
//
// This file translates authoritative Core loadout/catalog data into UI-facing
// models, runs trial-loadout legality checks through `LoadoutValidator`, and
// provides immutable slot update helpers for widgets.
//
// Keeping this logic centralized ensures picker screens stay aligned with Core
// rules (visibility, legality, and source constraints) without mutating
// loadouts directly in widget code.
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/loadout/loadout_validator.dart';
import 'package:runner_core/meta/ability_ownership_state.dart';
import 'package:runner_core/players/character_ability_namespace.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_catalog.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_catalog.dart';
import 'package:runner_core/weapons/weapon_id.dart';
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
/// [isOwned] is ownership state, while [isEnabled] is legality for the current
/// trial loadout. Keeping these separate lets UI distinguish locked from owned
/// but currently illegal candidates.
class AbilityPickerCandidate {
  const AbilityPickerCandidate({
    required this.id,
    required this.def,
    required this.isOwned,
    required this.isEnabled,
  });

  final AbilityKey id;
  final AbilityDef def;
  final bool isOwned;
  final bool isEnabled;
}

/// Display model for projectile payload selection.
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

  /// Selected learned spell id.
  final ProjectileId spellId;
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
/// It exposes learned projectile spells from ability ownership state.
class ProjectileSourcePanelModel {
  const ProjectileSourcePanelModel({
    required this.abilityOwnershipDisplayName,
    required this.spellOptions,
  });

  final String abilityOwnershipDisplayName;
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
  required AbilityOwnershipState abilityOwnership,
  ProjectileId? selectedSourceSpellId,
  bool overrideSelectedSource = false,
}) {
  final candidates = <AbilityDef>[
    for (final def in AbilityCatalog.abilities.values)
      if (_isAbilityVisibleForCharacter(characterId, def.id) &&
          def.allowedSlots.contains(slot))
        def,
  ];

  candidates.sort((a, b) => a.id.compareTo(b.id));

  return [
    for (final def in candidates)
      () {
        final isOwned = _isAbilityOwnedForSlot(
          slot: slot,
          abilityId: def.id,
          abilityOwnership: abilityOwnership,
        );
        return AbilityPickerCandidate(
          id: def.id,
          def: def,
          isOwned: isOwned,
          isEnabled: _isAbilityLegalForSlot(
            loadout: loadout,
            slot: slot,
            abilityId: def.id,
            selectedSourceSpellId: selectedSourceSpellId,
            overrideSelectedSource: overrideSelectedSource,
          ),
        );
      }(),
  ];
}

/// Returns projectile source options exposed by the character spell list.
ProjectileSourcePanelModel projectileSourcePanelModel(
  EquippedLoadoutDef loadout,
  AbilityOwnershipState abilityOwnership,
) {
  final spellOptions = <ProjectileSpellOption>[];
  final orderedLearned = abilityOwnership.learnedProjectileSpellIds.toList(
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
    abilityOwnershipDisplayName: 'Spell List',
    spellOptions: spellOptions,
  );
}

/// Returns flat projectile source options for compatibility with existing call sites.
List<ProjectileSourceOption> projectileSourceOptions(
  EquippedLoadoutDef loadout,
  AbilityOwnershipState abilityOwnership,
) {
  final sourceModel = projectileSourcePanelModel(loadout, abilityOwnership);
  final options = <ProjectileSourceOption>[];
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
  AbilityOwnershipState abilityOwnership,
  ProjectileId? selected,
) {
  if (selected == null) return null;
  final options = projectileSourceOptions(loadout, abilityOwnership);
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
  required ProjectileId selectedSpellId,
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

bool _isAbilityOwnedForSlot({
  required AbilitySlot slot,
  required AbilityKey abilityId,
  required AbilityOwnershipState abilityOwnership,
}) {
  return abilityOwnership.learnedAbilityIdsForSlot(slot).contains(abilityId);
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
  if (overrideSelectedSource &&
      slot == AbilitySlot.projectile &&
      selectedSourceSpellId != null) {
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
EquippedLoadoutDef _copyLoadout(
  EquippedLoadoutDef loadout, {
  int? mask,
  WeaponId? mainWeaponId,
  WeaponId? offhandWeaponId,
  SpellBookId? spellBookId,
  ProjectileId? projectileSlotSpellId,
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
    spellBookId: spellBookId ?? loadout.spellBookId,
    projectileSlotSpellId:
        projectileSlotSpellId ?? loadout.projectileSlotSpellId,
    accessoryId: accessoryId ?? loadout.accessoryId,
    abilityPrimaryId: abilityPrimaryId ?? loadout.abilityPrimaryId,
    abilitySecondaryId: abilitySecondaryId ?? loadout.abilitySecondaryId,
    abilityProjectileId: abilityProjectileId ?? loadout.abilityProjectileId,
    abilitySpellId: abilitySpellId ?? loadout.abilitySpellId,
    abilityMobilityId: abilityMobilityId ?? loadout.abilityMobilityId,
    abilityJumpId: abilityJumpId ?? loadout.abilityJumpId,
  );
}
