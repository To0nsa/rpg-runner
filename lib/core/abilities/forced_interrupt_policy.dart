import 'ability_catalog.dart';
import 'ability_def.dart';

/// Ability interruption policy backed by authored ability definitions.
///
/// Inject this policy where interruption rules are evaluated so all systems
/// resolve ability data through the same catalog instance.
class ForcedInterruptPolicy {
  const ForcedInterruptPolicy({this.abilities = AbilityCatalog.shared});

  /// Ability resolver used to fetch authored forced-interrupt settings.
  final AbilityResolver abilities;

  /// Shared default policy backed by the shipped static catalog.
  static const ForcedInterruptPolicy defaultPolicy = ForcedInterruptPolicy();

  /// Returns the forced-interrupt causes allowed for the given [abilityId].
  ///
  /// Falls back to [AbilityDef.defaultForcedInterruptCauses] when the ability
  /// id is null, empty, or unknown.
  Set<ForcedInterruptCause> forcedInterruptCausesForAbility(
    AbilityKey? abilityId,
  ) {
    if (abilityId == null || abilityId.isEmpty) {
      return AbilityDef.defaultForcedInterruptCauses;
    }
    final ability = abilities.resolve(abilityId);
    if (ability == null) return AbilityDef.defaultForcedInterruptCauses;
    return ability.forcedInterruptCauses;
  }

  /// Whether [abilityId] allows being forcibly interrupted by [cause].
  ///
  /// This is used by interruption systems to keep per-ability opt-in behavior
  /// centralized in authored ability data.
  bool abilityAllowsForcedInterrupt(
    AbilityKey? abilityId,
    ForcedInterruptCause cause,
  ) {
    return forcedInterruptCausesForAbility(abilityId).contains(cause);
  }
}
