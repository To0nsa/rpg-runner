import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../projectiles/projectile_catalog.dart';
import '../projectiles/projectile_id.dart';
import '../spellBook/spell_book_catalog.dart';
import '../spellBook/spell_book_id.dart';
import '../weapons/weapon_catalog.dart';
import '../weapons/weapon_id.dart';
import 'ability_def.dart';

/// Resolves menu/loadout-preview costs through the same payload rules as ECS.
AbilityResourceCost resolveEffectiveAbilityCostForLoadout({
  required AbilityDef ability,
  required EquippedLoadoutDef loadout,
  required AbilitySlot slot,
  WeaponCatalog weapons = const WeaponCatalog(),
  ProjectileCatalog projectiles = const ProjectileCatalog(),
  SpellBookCatalog spellBooks = const SpellBookCatalog(),
}) => ability.resolveCostForWeaponType(
  _resolvePayloadWeaponType(
    ability: ability,
    mainWeaponId: loadout.mainWeaponId,
    offhandWeaponId: loadout.offhandWeaponId,
    spellBookId: loadout.spellBookId,
    selectedSpellId: loadout.projectileSlotSpellId,
    slot: slot,
    weapons: weapons,
    projectiles: projectiles,
    spellBooks: spellBooks,
  ),
);

/// Resolves the effective commit cost for [ability] in [slot] for one loadout.
///
/// The resolved cost honors:
/// - [AbilityDef.defaultCost]
/// - [AbilityDef.costProfileByWeaponType]
/// - runtime payload source + currently selected projectile spell/weapon.
AbilityResourceCost resolveEffectiveAbilityCostForSlot({
  required AbilityDef ability,
  required EquippedLoadoutStore loadout,
  required int loadoutIndex,
  required AbilitySlot slot,
  required WeaponCatalog weapons,
  required ProjectileCatalog projectiles,
  required SpellBookCatalog spellBooks,
}) {
  final payloadWeaponType = resolvePayloadWeaponTypeForAbilitySlot(
    ability: ability,
    loadout: loadout,
    loadoutIndex: loadoutIndex,
    slot: slot,
    weapons: weapons,
    projectiles: projectiles,
    spellBooks: spellBooks,
  );
  return ability.resolveCostForWeaponType(payloadWeaponType);
}

/// Resolves the payload [WeaponType] that [ability] will use for [slot].
WeaponType? resolvePayloadWeaponTypeForAbilitySlot({
  required AbilityDef ability,
  required EquippedLoadoutStore loadout,
  required int loadoutIndex,
  required AbilitySlot slot,
  required WeaponCatalog weapons,
  required ProjectileCatalog projectiles,
  required SpellBookCatalog spellBooks,
}) => _resolvePayloadWeaponType(
  ability: ability,
  mainWeaponId: loadout.mainWeaponId[loadoutIndex],
  offhandWeaponId: loadout.offhandWeaponId[loadoutIndex],
  spellBookId: loadout.spellBookId[loadoutIndex],
  selectedSpellId: loadout.projectileSlotSpellId[loadoutIndex],
  slot: slot,
  weapons: weapons,
  projectiles: projectiles,
  spellBooks: spellBooks,
);

WeaponType? _resolvePayloadWeaponType({
  required AbilityDef ability,
  required WeaponId mainWeaponId,
  required WeaponId offhandWeaponId,
  required SpellBookId spellBookId,
  required ProjectileId selectedSpellId,
  required AbilitySlot slot,
  required WeaponCatalog weapons,
  required ProjectileCatalog projectiles,
  required SpellBookCatalog spellBooks,
}) {
  switch (ability.payloadSource) {
    case AbilityPayloadSource.none:
      return null;
    case AbilityPayloadSource.primaryWeapon:
      return weapons.tryGet(mainWeaponId)?.weaponType;
    case AbilityPayloadSource.secondaryWeapon:
      final main = weapons.tryGet(mainWeaponId);
      if (main != null && main.isTwoHanded) return main.weaponType;
      return weapons.tryGet(offhandWeaponId)?.weaponType;
    case AbilityPayloadSource.projectile:
      final projectileId = _resolveProjectilePayload(
        ability: ability,
        selectedSpellId: selectedSpellId,
        slot: slot,
        projectiles: projectiles,
      );
      if (projectileId == null) return null;
      return projectiles.tryGet(projectileId)?.weaponType;
    case AbilityPayloadSource.spellBook:
      return spellBooks.tryGet(spellBookId)?.weaponType;
  }
}

/// Resolves the projectile item id that ability payload should use for [slot].
///
/// For projectile slot abilities this uses the selected projectile spell.
ProjectileId? resolveProjectilePayloadForAbilitySlot({
  required AbilityDef ability,
  required EquippedLoadoutStore loadout,
  required int loadoutIndex,
  required AbilitySlot slot,
  required ProjectileCatalog projectiles,
}) => _resolveProjectilePayload(
  ability: ability,
  selectedSpellId: loadout.projectileSlotSpellId[loadoutIndex],
  slot: slot,
  projectiles: projectiles,
);

ProjectileId? _resolveProjectilePayload({
  required AbilityDef ability,
  required ProjectileId selectedSpellId,
  required AbilitySlot slot,
  required ProjectileCatalog projectiles,
}) {
  if (slot != AbilitySlot.projectile) return null;
  final selectedSpell = projectiles.tryGet(selectedSpellId);
  final supportsSpell =
      selectedSpell != null &&
      selectedSpell.weaponType == WeaponType.spell &&
      (ability.requiredWeaponTypes.isEmpty ||
          ability.requiredWeaponTypes.contains(WeaponType.spell));
  if (supportsSpell) return selectedSpellId;
  return null;
}
