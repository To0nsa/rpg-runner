import 'catalog/common_ability_defs.dart';
import 'catalog/eloise_ability_defs.dart';
import 'ability_def.dart';

/// Read-only ability definition lookup contract.
///
/// Systems should depend on this interface so tests and alternate catalogs can
/// be injected without coupling to static globals.
abstract interface class AbilityResolver {
  /// Returns the authored ability for [key], or null when unknown.
  AbilityDef? resolve(AbilityKey key);
}

/// Static registry of all available abilities.
///
/// This is currently code-authored data to keep ability tuning deterministic
/// and reviewable in source control.
class AbilityCatalog implements AbilityResolver {
  const AbilityCatalog();

  /// Shared default resolver for convenience call sites.
  static const AbilityCatalog shared = AbilityCatalog();

  /// Complete ability definition table keyed by [AbilityKey].
  ///
  /// Keys should remain stable because they are referenced by loadouts, tests,
  /// and persisted run/telemetry data.
  static final Map<AbilityKey, AbilityDef> abilities =
      Map<AbilityKey, AbilityDef>.unmodifiable(<AbilityKey, AbilityDef>{
        ...commonAbilityDefs,
        ...eloiseAbilityDefs,
      });

  static final bool _integrityChecked = _validateIntegrity();

  static bool _validateIntegrity() {
    assert(() {
      final seenIds = <AbilityKey>{};
      for (final entry in abilities.entries) {
        final key = entry.key;
        final def = entry.value;
        if (key != def.id) {
          throw StateError(
            'AbilityCatalog key "$key" does not match AbilityDef.id "${def.id}".',
          );
        }
        if (!seenIds.add(def.id)) {
          throw StateError('Duplicate AbilityDef.id "${def.id}" in catalog.');
        }
      }
      return true;
    }());
    return true;
  }

  @override
  AbilityDef? resolve(AbilityKey key) {
    assert(_integrityChecked);
    return abilities[key];
  }
}
