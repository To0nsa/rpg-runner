import 'ability_catalog.dart';
import 'ability_def.dart';

Set<ForcedInterruptCause> forcedInterruptCausesForAbility(
  AbilityKey? abilityId,
) {
  if (abilityId == null || abilityId.isEmpty) {
    return AbilityDef.defaultForcedInterruptCauses;
  }
  final ability = AbilityCatalog.tryGet(abilityId);
  if (ability == null) return AbilityDef.defaultForcedInterruptCauses;
  return ability.forcedInterruptCauses;
}

bool abilityAllowsForcedInterrupt(
  AbilityKey? abilityId,
  ForcedInterruptCause cause,
) {
  return forcedInterruptCausesForAbility(abilityId).contains(cause);
}
