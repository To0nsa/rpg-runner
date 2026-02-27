import '../../../../core/abilities/ability_def.dart';
import '../../../../core/projectiles/projectile_id.dart';

/// Maps an ability definition to the weapon context used by tooltip text.
///
/// Projectile abilities resolve differently depending on whether the projectile
/// slot is currently bound to a spell projectile or the throwing weapon.
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
        return WeaponType.spell;
      }
      return WeaponType.throwingWeapon;
    case AbilityPayloadSource.spellBook:
      return WeaponType.spell;
  }
}
