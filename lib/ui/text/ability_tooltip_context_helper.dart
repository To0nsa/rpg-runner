import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';

/// Maps an ability definition to the payload context used by tooltip text.
///
/// Projectile abilities resolve differently depending on whether the
/// projectile slot is currently bound to a spell projectile.
WeaponType? payloadWeaponTypeForTooltip({
  required AbilityDef def,
  required AbilitySlot slot,
  required ProjectileId? selectedSourceSpellId,
}) {
  switch (def.payloadSource) {
    case AbilityPayloadSource.none:
      return null;
    case AbilityPayloadSource.primaryWeapon:
      return null;
    case AbilityPayloadSource.secondaryWeapon:
      return null;
    case AbilityPayloadSource.projectile:
      if (slot == AbilitySlot.projectile && selectedSourceSpellId != null) {
        return const ProjectileCatalog()
            .tryGet(selectedSourceSpellId)
            ?.weaponType;
      }
      return null;
    case AbilityPayloadSource.spellBook:
      return def.requiredWeaponTypes.contains(WeaponType.fieldKit)
          ? WeaponType.fieldKit
          : WeaponType.spell;
  }
}
