import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../projectiles/projectile_catalog.dart';
import '../projectiles/projectile_id.dart';
import '../spellBook/spell_book_catalog.dart';
import '../weapons/weapon_catalog.dart';
import 'ability_def.dart';

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
}) {
  switch (ability.payloadSource) {
    case AbilityPayloadSource.none:
      return null;
    case AbilityPayloadSource.primaryWeapon:
      return weapons.tryGet(loadout.mainWeaponId[loadoutIndex])?.weaponType;
    case AbilityPayloadSource.secondaryWeapon:
      final mainId = loadout.mainWeaponId[loadoutIndex];
      final main = weapons.tryGet(mainId);
      if (main != null && main.isTwoHanded) return main.weaponType;
      return weapons.tryGet(loadout.offhandWeaponId[loadoutIndex])?.weaponType;
    case AbilityPayloadSource.projectile:
      final projectileId = resolveProjectilePayloadForAbilitySlot(
        ability: ability,
        loadout: loadout,
        loadoutIndex: loadoutIndex,
        slot: slot,
        projectiles: projectiles,
        spellBooks: spellBooks,
      );
      return projectiles.tryGet(projectileId)?.weaponType;
    case AbilityPayloadSource.spellBook:
      return spellBooks.tryGet(loadout.spellBookId[loadoutIndex])?.weaponType;
  }
}

/// Resolves the projectile item id that ability payload should use for [slot].
///
/// For projectile slot abilities this will prefer a selected projectile spell
/// from the equipped spellbook when valid; otherwise it falls back to the
/// equipped projectile item.
ProjectileId resolveProjectilePayloadForAbilitySlot({
  required AbilityDef ability,
  required EquippedLoadoutStore loadout,
  required int loadoutIndex,
  required AbilitySlot slot,
  required ProjectileCatalog projectiles,
  required SpellBookCatalog spellBooks,
}) {
  final selectedSpellId = slot == AbilitySlot.projectile
      ? loadout.projectileSlotSpellId[loadoutIndex]
      : null;
  if (selectedSpellId != null) {
    final selectedSpell = projectiles.tryGet(selectedSpellId);
    final spellBook = spellBooks.tryGet(loadout.spellBookId[loadoutIndex]);
    final supportsSpell =
        selectedSpell != null &&
        selectedSpell.weaponType == WeaponType.spell &&
        spellBook != null &&
        spellBook.containsProjectileSpell(selectedSpellId) &&
        (ability.requiredWeaponTypes.isEmpty ||
            ability.requiredWeaponTypes.contains(WeaponType.spell));
    if (supportsSpell) return selectedSpellId;
  }
  return loadout.projectileId[loadoutIndex];
}
